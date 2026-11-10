trigger ContactTrigger on Contact(before insert, after insert, after update, before delete, after delete, after undelete) {

    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete || Trigger.isUndelete)) {
        ContactTriggerHandler.reCalculateContacts(Trigger.newMap, Trigger.oldMap);
    }
}