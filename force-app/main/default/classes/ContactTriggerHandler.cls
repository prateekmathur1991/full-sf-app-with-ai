public class ContactTriggerHandler {
    
    public static void reCalculateContacts(Map<Id, Contact> newMap, Map<Id, Contact> oldMap) {

        Set<Id> affectedAccountIdSet = new Set<Id>();

        Map<Id, Contact> mapToIterate = newMap ?? oldMap;
        
        for (Id contactId : mapToIterate.keySet()) {
            if (newMap?.get(contactId)?.AccountId != oldMap?.get(contactId)?.AccountId) {
                addIfNull(affectedAccountIdSet, newMap?.get(contactId)?.AccountId);
                addIfNull(affectedAccountIdSet, oldMap?.get(contactId)?.AccountId);
            }
        }

        if (affectedAccountIdSet.isEmpty()) {
            return;
        }

        Map<Id, Integer> accountToContactCountMap = new Map<Id, Integer>();

        for (AggregateResult aggResult : [SELECT AccountId, COUNT(Id) conCount FROM Contact WHERE AccountId IN :affectedAccountIdSet GROUP BY AccountId]) {
            String accountId = String.valueOf(aggResult.get('AccountId'));
            Integer conCount = Integer.valueOf(aggResult.get('conCount'));
            accountToContactCountMap.put(accountId, conCount);
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Id affectedAccountId : affectedAccountIdSet) {
            accountsToUpdate.add(new Account(Id = affectedAccountId, Contact_Count__c = accountToContactCountMap.get(affectedAccountId) ?? 0));
        }

        update accountsToUpdate;
    }

    private static void addIfNull(Set<Id> idSet, Id value) {
        if (value != null) {
            idSet.add(value);
        }
    }
}