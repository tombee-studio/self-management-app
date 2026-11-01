'use strict';
const {fail}=require('../domain/model');
// Event effects depend on the immutable envelope, not the current ledger generation.
async function deliverEvents({store,owner,consumerId,apply,events:providedEvents}) {
 const events=providedEvents||await store.all(owner,'events');
 for(const record of events) {
  if(record.schemaVersion!==2)fail('UnsupportedVersion');
  const receiptId=`event-consumer#${consumerId}#${record.eventId}`;
  if(await store.get(owner,'metadata',receiptId))continue;
  const {deliveryState,...envelope}=record;
  const writes=await apply(envelope);
  if(writes.some(x=>x.table!=='metadata'||x.id===receiptId))fail('InvariantViolation');
  await store.deliver(owner,receiptId,record,writes);
 }
}
module.exports={deliverEvents};
