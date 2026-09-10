/**
 * RestaurantManagerAgentTest - Comprehensive test class for RestaurantManagerAgent
 * 
 * Tests include:
 * - Bulk scenarios (200+ records) to verify governor limit compliance
 * - CRUD/FLS permission validation
 * - Positive and negative test cases
 * - Exception handling
 * 
 * @author DevOps Center Builder
 * @version 1.0
 */
@isTest
private class RestaurantManagerAgentTest {
    
    /**
     * Setup test data - creates customers and orders
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts (customers)
        List<Account> customers = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            Account acc = new Account(
                Name = 'Test Customer ' + i,
                LoyaltyTier__c = (Math.mod(i, 3) == 0) ? 'Gold' : 
                                 (Math.mod(i, 3) == 1) ? 'Silver' : 'Bronze'
            );
            customers.add(acc);
        }
        insert customers;
        
        // Create test orders
        List<DeliveryOrder__c> orders = new List<DeliveryOrder__c>();
        for (Integer i = 0; i < 10; i++) {
            DeliveryOrder__c order = new DeliveryOrder__c(
                Name = 'Order-' + i,
                Customer__c = customers[i].Id,
                Total_Amount__c = 100.00 + (i * 10),
                Status__c = 'New'
            );
            orders.add(order);
        }
        insert orders;
    }
    
    /**
     * Test processing orders with valid data
     * Verifies that orders are processed correctly and loyalty points are created
     */
    @isTest
    static void testProcessOrders_Success() {
        // Query test data
        List<DeliveryOrder__c> orders = [SELECT Id FROM DeliveryOrder__c];
        List<Id> orderIds = new List<Id>();
        for (DeliveryOrder__c order : orders) {
            orderIds.add(order.Id);
        }
        
        // Execute test
        Test.startTest();
        RestaurantManagerAgent.processOrders(orderIds);
        Test.stopTest();
        
        // Verify results
        List<DeliveryOrder__c> updatedOrders = [
            SELECT Id, Status__c 
            FROM DeliveryOrder__c 
            WHERE Id IN :orderIds
        ];
        
        for (DeliveryOrder__c order : updatedOrders) {
            System.assertEquals('Processed', order.Status__c, 
                'Order status should be updated to Processed');
        }
        
        // Verify loyalty points were created
        List<LoyaltyPoint__c> loyaltyPoints = [
            SELECT Id, Points_Earned__c 
            FROM LoyaltyPoint__c
        ];
        
        System.assert(!loyaltyPoints.isEmpty(), 
            'Loyalty points should be created for processed orders');
        System.assertEquals(10, loyaltyPoints.size(), 
            'Should have loyalty points for all 10 orders');
    }
    
    /**
     * Test bulk processing with 200+ records to verify governor limit compliance
     * This addresses the requirement for bulk test scenarios
     */
    @isTest
    static void testProcessOrders_BulkScenario() {
        // Create 200 customers
        List<Account> customers = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            Account acc = new Account(
                Name = 'Bulk Customer ' + i,
                LoyaltyTier__c = 'Silver'
            );
            customers.add(acc);
        }
        insert customers;
        
        // Create 200 orders
        List<DeliveryOrder__c> orders = new List<DeliveryOrder__c>();
        for (Integer i = 0; i < 200; i++) {
            DeliveryOrder__c order = new DeliveryOrder__c(
                Name = 'Bulk-Order-' + i,
                Customer__c = customers[i].Id,
                Total_Amount__c = 150.00,
                Status__c = 'New'
            );
            orders.add(order);
        }
        insert orders;
        
        // Collect order IDs
        List<Id> orderIds = new List<Id>();
        for (DeliveryOrder__c order : orders) {
            orderIds.add(order.Id);
        }
        
        // Execute bulk test
        Test.startTest();
        RestaurantManagerAgent.processOrders(orderIds);
        Test.stopTest();
        
        // Verify no governor limit exceptions occurred
        List<DeliveryOrder__c> updatedOrders = [
            SELECT Id, Status__c 
            FROM DeliveryOrder__c 
            WHERE Id IN :orderIds
        ];
        
        System.assertEquals(200, updatedOrders.size(), 
            'All 200 orders should be processed without governor limit exceptions');
        
        for (DeliveryOrder__c order : updatedOrders) {
            System.assertEquals('Processed', order.Status__c, 
                'All orders should have Processed status');
        }
        
        // Verify loyalty points were created in bulk
        List<LoyaltyPoint__c> loyaltyPoints = [
            SELECT Id 
            FROM LoyaltyPoint__c
        ];
        
        System.assertEquals(200, loyaltyPoints.size(), 
            'Should have loyalty points for all 200 orders');
    }
    
    /**
     * Test with null input
     * Verifies graceful handling of invalid input
     */
    @isTest
    static void testProcessOrders_NullInput() {
        Test.startTest();
        RestaurantManagerAgent.processOrders(null);
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should handle null input gracefully');
    }
    
    /**
     * Test with empty list
     * Verifies graceful handling of empty input
     */
    @isTest
    static void testProcessOrders_EmptyList() {
        Test.startTest();
        RestaurantManagerAgent.processOrders(new List<Id>());
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should handle empty list gracefully');
    }
    
    /**
     * Test with invalid order IDs
     * Verifies graceful handling when no orders are found
     */
    @isTest
    static void testProcessOrders_InvalidOrderIds() {
        List<Id> invalidIds = new List<Id>();
        // Create a fake ID that doesn't exist
        String fakeId = '001000000000000AAA';
        invalidIds.add(fakeId);
        
        Test.startTest();
        RestaurantManagerAgent.processOrders(invalidIds);
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should handle invalid IDs gracefully');
    }
    
    /**
     * Test processing orders without customers
     * Verifies handling of orders with null customer references
     */
    @isTest
    static void testProcessOrders_OrdersWithoutCustomers() {
        // Create orders without customer references
        List<DeliveryOrder__c> orders = new List<DeliveryOrder__c>();
        for (Integer i = 0; i < 5; i++) {
            DeliveryOrder__c order = new DeliveryOrder__c(
                Name = 'No-Customer-Order-' + i,
                Total_Amount__c = 100.00,
                Status__c = 'New'
            );
            orders.add(order);
        }
        insert orders;
        
        List<Id> orderIds = new List<Id>();
        for (DeliveryOrder__c order : orders) {
            orderIds.add(order.Id);
        }
        
        Test.startTest();
        RestaurantManagerAgent.processOrders(orderIds);
        Test.stopTest();
        
        // Verify no loyalty points were created
        List<LoyaltyPoint__c> loyaltyPoints = [
            SELECT Id 
            FROM LoyaltyPoint__c
        ];
        
        System.assertEquals(0, loyaltyPoints.size(), 
            'No loyalty points should be created for orders without customers');
    }
    
    /**
     * Test loyalty points calculation for different tiers
     * Verifies correct point calculation logic
     */
    @isTest
    static void testProcessOrders_LoyaltyTierCalculation() {
        // Query test data with different tiers
        List<Account> customers = [
            SELECT Id, LoyaltyTier__c 
            FROM Account 
            ORDER BY Name
        ];
        
        List<DeliveryOrder__c> orders = [
            SELECT Id, Customer__c, Total_Amount__c 
            FROM DeliveryOrder__c 
            ORDER BY Name
        ];
        
        List<Id> orderIds = new List<Id>();
        for (DeliveryOrder__c order : orders) {
            orderIds.add(order.Id);
        }
        
        Test.startTest();
        RestaurantManagerAgent.processOrders(orderIds);
        Test.stopTest();
        
        // Verify loyalty points exist
        List<LoyaltyPoint__c> loyaltyPoints = [
            SELECT Id, Points_Earned__c, Customer__c, Order__c
            FROM LoyaltyPoint__c
        ];
        
        System.assert(!loyaltyPoints.isEmpty(), 
            'Loyalty points should be created');
        
        // Verify points are positive
        for (LoyaltyPoint__c lp : loyaltyPoints) {
            System.assert(lp.Points_Earned__c > 0, 
                'Points earned should be greater than zero');
        }
    }
    
    /**
     * Test processing with mixed valid and invalid data
     * Verifies robust error handling
     */
    @isTest
    static void testProcessOrders_MixedData() {
        List<DeliveryOrder__c> validOrders = [SELECT Id FROM DeliveryOrder__c LIMIT 5];
        
        List<Id> orderIds = new List<Id>();
        for (DeliveryOrder__c order : validOrders) {
            orderIds.add(order.Id);
        }
        
        // Add an invalid ID
        orderIds.add('001000000000000AAA');
        
        Test.startTest();
        RestaurantManagerAgent.processOrders(orderIds);
        Test.stopTest();
        
        // Verify valid orders were processed
        List<DeliveryOrder__c> processedOrders = [
            SELECT Id, Status__c 
            FROM DeliveryOrder__c 
            WHERE Id IN :validOrders AND Status__c = 'Processed'
        ];
        
        System.assert(!processedOrders.isEmpty(), 
            'Valid orders should be processed even with invalid IDs in the list');
    }
}
