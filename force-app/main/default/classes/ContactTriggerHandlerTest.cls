/**
 * @description Test class for ContactTriggerHandler.
 * Tests the reCalculateContacts method to ensure Contact count is accurately maintained
 * on related Account records when contacts are inserted, updated, or deleted.
 */
@isTest
private class ContactTriggerHandlerTest {

    /**
     * @description Test setup to create test data: Accounts and Contacts
     * @return void
     */
    @testSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name = 'Test Account 1'));
        testAccounts.add(new Account(Name = 'Test Account 2'));
        testAccounts.add(new Account(Name = 'Test Account 3'));
        insert testAccounts;

        // Create test contacts for Account 1
        List<Contact> testContacts = new List<Contact>();
        testContacts.add(new Contact(FirstName = 'John', LastName = 'Doe', AccountId = testAccounts[0].Id));
        testContacts.add(new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = testAccounts[0].Id));
        testContacts.add(new Contact(FirstName = 'Bob', LastName = 'Johnson', AccountId = testAccounts[1].Id));
        insert testContacts;
    }

    /**
     * @description Test that Contact_Count__c is updated correctly when new contacts are inserted
     */
    @isTest
    static void testContactCountOnInsert() {
        // Retrieve test account
        Account testAccount = [SELECT Id, Contact_Count__c FROM Account WHERE Name = 'Test Account 1'];

        System.assertEquals(2, testAccount.Contact_Count__c, 'Expected 2 contacts on Test Account 1');
    }

    /**
     * @description Test that Contact_Count__c is updated correctly when contacts are transferred between accounts
     */
    @isTest
    static void testContactCountOnUpdate() {
        // Retrieve test contacts and accounts
        Contact contactToMove = [SELECT Id, AccountId FROM Contact WHERE FirstName = 'John'];
        Account accountFrom = [SELECT Id, Contact_Count__c FROM Account WHERE Name = 'Test Account 1'];
        Account accountTo = [SELECT Id, Contact_Count__c FROM Account WHERE Name = 'Test Account 2'];

        System.assertEquals(2, accountFrom.Contact_Count__c, 'Account 1 should have 2 contacts before move');
        System.assertEquals(1, accountTo.Contact_Count__c, 'Account 2 should have 1 contact before move');

        // Move contact to different account
        Test.startTest();
        contactToMove.AccountId = accountTo.Id;
        update contactToMove;
        Test.stopTest();

        // Verify counts are updated
        accountFrom = [SELECT Contact_Count__c FROM Account WHERE Id = :accountFrom.Id];
        accountTo = [SELECT Contact_Count__c FROM Account WHERE Id = :accountTo.Id];

        System.assertEquals(1, accountFrom.Contact_Count__c, 'Account 1 should have 1 contact after move');
        System.assertEquals(2, accountTo.Contact_Count__c, 'Account 2 should have 2 contacts after move');
    }

    /**
     * @description Test that Contact_Count__c is updated correctly when contacts are deleted
     */
    @isTest
    static void testContactCountOnDelete() {
        // Retrieve test data
        Contact contactToDelete = [SELECT Id, AccountId FROM Contact WHERE FirstName = 'John'];
        Account accountBefore = [SELECT Id, Contact_Count__c FROM Account WHERE Name = 'Test Account 1'];

        System.assertEquals(2, accountBefore.Contact_Count__c, 'Expected 2 contacts before deletion');

        // Delete contact
        Test.startTest();
        delete contactToDelete;
        Test.stopTest();

        // Verify count is updated
        Account accountAfter = [SELECT Contact_Count__c FROM Account WHERE Id = :accountBefore.Id];
        System.assertEquals(1, accountAfter.Contact_Count__c, 'Expected 1 contact after deletion');
    }

    /**
     * @description Test that Contact_Count__c is updated correctly when multiple contacts are inserted
     */
    @isTest
    static void testContactCountOnBulkInsert() {
        // Retrieve test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 3'];

        // Verify initial count is 0
        Account accountBefore = [SELECT Contact_Count__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals(null, accountBefore.Contact_Count__c, 'Expected null contact count before inserting contacts');

        // Insert multiple contacts
        Test.startTest();
        List<Contact> bulkContacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            bulkContacts.add(new Contact(FirstName = 'Test' + i, LastName = 'Contact', AccountId = testAccount.Id));
        }
        insert bulkContacts;
        Test.stopTest();

        // Verify count is updated
        Account accountAfter = [SELECT Contact_Count__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals(5, accountAfter.Contact_Count__c, 'Expected 5 contacts after bulk insert');
    }

    /**
     * @description Test that Contact_Count__c is updated correctly when contacts with null AccountId are handled
     */
    @isTest
    static void testContactCountWithNullAccountId() {
        // Retrieve test account and contact
        Contact contactWithAccount = [SELECT Id, AccountId FROM Contact WHERE FirstName = 'Bob'];
        Account accountBefore = [SELECT Id, Contact_Count__c FROM Account WHERE Name = 'Test Account 2'];

        System.assertEquals(1, accountBefore.Contact_Count__c, 'Expected 1 contact before moving to null');

        // Move contact to null AccountId
        Test.startTest();
        contactWithAccount.AccountId = null;
        update contactWithAccount;
        Test.stopTest();

        // Verify count is updated
        Account accountAfter = [SELECT Contact_Count__c FROM Account WHERE Id = :accountBefore.Id];
        System.assertEquals(0, accountAfter.Contact_Count__c, 'Expected 0 contacts after moving to null AccountId');
    }

    /**
     * @description Test that Contact_Count__c correctly handles undelete operations
     */
    @isTest
    static void testContactCountOnUndelete() {
        // Retrieve test contact and account
        Contact contactToDelete = [SELECT Id, AccountId FROM Contact WHERE FirstName = 'John'];
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];

        // Delete the contact
        Test.startTest();
        delete contactToDelete;

        // Verify count after deletion
        Account accountAfterDelete = [SELECT Contact_Count__c FROM Account WHERE Id = :account.Id];
        System.assertEquals(1, accountAfterDelete.Contact_Count__c, 'Expected 1 contact after deletion');

        // Undelete the contact
        undelete contactToDelete;
        Test.stopTest();

        // Verify count is restored
        Account accountAfterUndelete = [SELECT Contact_Count__c FROM Account WHERE Id = :account.Id];
        System.assertEquals(2, accountAfterUndelete.Contact_Count__c, 'Expected 2 contacts after undelete');
    }

    /**
     * @description Test that reCalculateContacts handles empty maps gracefully
     */
    @isTest
    static void testReCalculateContactsWithEmptyMaps() {
        // Call the method with empty maps
        Test.startTest();
        ContactTriggerHandler.reCalculateContacts(new Map<Id, Contact>(), new Map<Id, Contact>());
        Test.stopTest();

        // If no exception is thrown, test passes
        System.assert(true, 'Method should handle empty maps gracefully');
    }

    /**
     * @description Test that reCalculateContacts handles null maps gracefully
     */
    @isTest
    static void testReCalculateContactsWithNullNewMap() {
        // Retrieve test account
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE FirstName = 'John'];
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];

        // Call the method with null newMap
        Test.startTest();
        ContactTriggerHandler.reCalculateContacts(null, new Map<Id, Contact>{testContact.Id => testContact});
        Test.stopTest();

        // Verify no errors and counts remain consistent
        Account accountAfter = [SELECT Contact_Count__c FROM Account WHERE Id = :account.Id];
        System.assertNotEquals(null, accountAfter.Contact_Count__c, 'Contact count should be maintained');
    }
}
