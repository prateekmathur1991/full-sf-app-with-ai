/**
 * @author Salesforce Developer
 * @description Test class for Case_Selector. Verifies that Case records are correctly queried and
 *              keyed by CaseNumber, and that empty/null input is handled gracefully.
 */
@isTest
private class Case_Selector_Test {
    @isTest
    static void testSelectByCaseNumbersReturnsMatchingCases() {
        Case testCase = new Case(Subject = 'Test Case Subject', Status = 'New');
        insert testCase;
        testCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :testCase.Id];

        Test.startTest();
        Map<String, Case> results = new Case_Selector().selectByCaseNumbers(new Set<String>{ testCase.CaseNumber });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one matching case');
        System.assertEquals(testCase.Id, results.get(testCase.CaseNumber).Id, 'Expected the case to be keyed by CaseNumber');
    }

    @isTest
    static void testSelectByCaseNumbersWithEmptySetReturnsEmptyMap() {
        Test.startTest();
        Map<String, Case> results = new Case_Selector().selectByCaseNumbers(new Set<String>());
        Test.stopTest();

        System.assert(results.isEmpty(), 'Expected an empty map when no case numbers are provided');
    }

    @isTest
    static void testSelectByCaseNumbersWithNullReturnsEmptyMap() {
        Test.startTest();
        Map<String, Case> results = new Case_Selector().selectByCaseNumbers(null);
        Test.stopTest();

        System.assert(results.isEmpty(), 'Expected an empty map when null is provided');
    }
}
