/**
 * RestaurantManagerAgent - Manages restaurant operations including orders, reservations, and inventory
 * 
 * This class has been refactored to address Critical and High severity issues:
 * - SOQL queries moved outside loops (bulkified)
 * - DML operations moved outside loops (bulkified)
 * - Nested loops eliminated using Map-based lookups
 * - CRUD/FLS permission checks added per governance policy a2Rxx000000002AAA
 * 
 * @author DevOps Center Builder
 * @version 1.0
 */
public with sharing class RestaurantManagerAgent {
    
    /**
     * Process multiple restaurant orders with proper bulkification
     * @param orderIds List of order IDs to process
     */
    public static void processOrders(List<Id> orderIds) {
        // Validate input
        if (orderIds == null || orderIds.isEmpty()) {
            return;
        }
        
        // CRUD check before SOQL query - using WITH USER_MODE (API v56+)
        // This satisfies governance policy: Enforce_CRUD_FLS_Checks (a2Rxx000000002AAA v1.0.0)
        List<DeliveryOrder__c> orders = [
            SELECT Id, Name, Status__c, Total_Amount__c, Customer__c
            FROM DeliveryOrder__c 
            WHERE Id IN :orderIds
            WITH USER_MODE
        ];
        
        if (orders.isEmpty()) {
            return;
        }
        
        // Bulkified SOQL: Collect all customer IDs first, then query once
        Set<Id> customerIds = new Set<Id>();
        for (DeliveryOrder__c order : orders) {
            if (order.Customer__c != null) {
                customerIds.add(order.Customer__c);
            }
        }
        
        // Single SOQL query outside loop - addresses "SOQL Query in Loop" violation
        Map<Id, Account> customerMap = new Map<Id, Account>();
        if (!customerIds.isEmpty()) {
            for (Account customer : [
                SELECT Id, Name, LoyaltyTier__c, LoyaltyPoints__c
                FROM Account 
                WHERE Id IN :customerIds
                WITH USER_MODE
            ]) {
                customerMap.put(customer.Id, customer);
            }
        }
        
        // Process orders using Map lookup instead of nested loop
        // This eliminates O(n²) complexity and addresses "Nested For Loops" violation
        List<LoyaltyPoint__c> loyaltyPointsToInsert = new List<LoyaltyPoint__c>();
        List<DeliveryOrder__c> ordersToUpdate = new List<DeliveryOrder__c>();
        
        for (DeliveryOrder__c order : orders) {
            // Map-based lookup - O(1) instead of O(n) nested loop
            Account customer = customerMap.get(order.Customer__c);
            
            if (customer != null) {
                // Calculate loyalty points
                Decimal points = calculateLoyaltyPoints(order.Total_Amount__c, customer.LoyaltyTier__c);
                
                if (points > 0) {
                    // Accumulate records for bulk DML
                    LoyaltyPoint__c loyaltyPoint = new LoyaltyPoint__c(
                        Customer__c = customer.Id,
                        Order__c = order.Id,
                        Points_Earned__c = points,
                        Transaction_Date__c = System.today()
                    );
                    loyaltyPointsToInsert.add(loyaltyPoint);
                }
                
                // Mark order as processed
                order.Status__c = 'Processed';
                ordersToUpdate.add(order);
            }
        }
        
        // CRUD check before DML operations
        // Addresses "Missing CRUD Permission Check" violation (CWE-862: Missing Authorization)
        if (!loyaltyPointsToInsert.isEmpty()) {
            if (Schema.sObjectType.LoyaltyPoint__c.isCreateable()) {
                // Bulk DML outside loop - addresses "DML Operation in Loop" violation
                insert loyaltyPointsToInsert;
            } else {
                throw new SecurityException('Insufficient permissions to create LoyaltyPoint__c records');
            }
        }
        
        if (!ordersToUpdate.isEmpty()) {
            if (Schema.sObjectType.DeliveryOrder__c.isUpdateable()) {
                // Bulk DML outside loop
                update ordersToUpdate;
            } else {
                throw new SecurityException('Insufficient permissions to update DeliveryOrder__c records');
            }
        }
    }
    
    /**
     * Calculate loyalty points based on order amount and customer tier
     * @param amount Order total amount
     * @param tier Customer loyalty tier
     * @return Calculated loyalty points
     */
    private static Decimal calculateLoyaltyPoints(Decimal amount, String tier) {
        if (amount == null || amount <= 0) {
            return 0;
        }
        
        Decimal multiplier = 1.0;
        if (tier == 'Gold') {
            multiplier = 2.0;
        } else if (tier == 'Silver') {
            multiplier = 1.5;
        }
        
        return amount * multiplier * 0.01; // 1% to 2% of order value
    }
    
    /**
     * Custom exception for security-related errors
     */
    public class SecurityException extends Exception {}
}
