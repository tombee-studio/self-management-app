const {test}=require('node:test');const assert=require('node:assert/strict');const {MemoryStore}=require('./support');const {deliverEvents}=require('../application/deliver_events');
test('event v2 consumer commits effects/receipt/delivery atomically and rejects v1',async()=>{
 const store=new MemoryStore();const event={eventId:'e/1/ExpenseRecorded',schemaVersion:2,eventType:'ExpenseRecorded',deliveryState:'pending'};
 store.tables.events.set('o/'+event.eventId,event);
 let calls=0;const options={store,owner:'o',consumerId:'test',apply:async event=>{assert.equal('deliveryState' in event,false);calls++;return [{table:'metadata',id:'effect',data:{count:1}}];}};
 store.beforeCommit=()=>{throw Error('failure');};await assert.rejects(deliverEvents(options));assert.equal(await store.get('o','metadata','effect'),null);
 store.beforeCommit=null;await deliverEvents(options);const n=calls;await deliverEvents(options);assert.equal(calls,n);assert.equal((await store.get('o','metadata','effect')).count,1);
 store.tables.events.set('o/old',{eventId:'old',schemaVersion:1});await assert.rejects(deliverEvents(options),{code:'UnsupportedVersion'});
});
