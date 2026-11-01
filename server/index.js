'use strict';
const {DynamoDBClient}=require('@aws-sdk/client-dynamodb');
const sdk=require('@aws-sdk/lib-dynamodb');
const {randomUUID}=require('node:crypto');
const {DynamoStore}=require('./infrastructure/dynamodb');
const {Tokens}=require('./infrastructure/tokens');
const {Service}=require('./application/service');
const {createHandler}=require('./api/handler');
const client=sdk.DynamoDBDocumentClient.from(new DynamoDBClient({}));
const tables={expenses:process.env.EXPENSES_TABLE,categories:process.env.CATEGORIES_TABLE,budgets:process.env.BUDGETS_TABLE,metadata:process.env.METADATA_TABLE,events:process.env.EVENTS_TABLE};
exports.handler=async(event,context)=>{
 const store=new DynamoStore(client,sdk,tables,()=>context.getRemainingTimeInMillis()<1500);
 if(event.Records?.every(r=>r.eventSource==='aws:dynamodb')) {
  const {deliverEvents}=require('./application/deliver_events');
  const {unmarshall}=require('@aws-sdk/util-dynamodb');
  const groups=new Map();
  for(const record of event.Records) {
   if(record.eventName!=='INSERT'||!record.dynamodb?.NewImage)continue;
   const item=unmarshall(record.dynamodb.NewImage);
   if(item.ownerId!==process.env.OWNER_ID||item.data.deliveryState!=='pending')continue;
   if(!groups.has(item.ownerId))groups.set(item.ownerId,[]);
   groups.get(item.ownerId).push(item.data);
  }
  for(const [owner,events] of groups)await deliverEvents({store,owner,events,consumerId:'commit-audit',apply:async envelope=>{
   // No sensitive payload logging. The transactional consumer receipt is the audit effect.
   const {matches}=require('./api/schema');
   if(!matches(envelope,require('./contracts/events.schema.json')))throw Error('Invalid domain event');
   return [];
  }});
  return {};
 }
 return createHandler(new Service({store,tokens:new Tokens(process.env.CURSOR_SECRET),uuid:randomUUID}),process.env.OWNER_ID)(event);
};
