'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const sdk=require('@aws-sdk/lib-dynamodb');
const {marshall}=require('@aws-sdk/util-dynamodb');

test('Lambda stream adapter acknowledges committed v2 events once and ignores delivery updates',async()=>{
 const records=new Map();let transactions=0;
 const client={send:async command=>{
  const p=command.input;
  if(command instanceof sdk.GetCommand)return {Item:records.get(p.TableName+'/'+p.Key.id)};
  if(command instanceof sdk.QueryCommand)return {Items:[...records].filter(([key])=>key.startsWith(p.TableName+'/')).map(([,value])=>value)};
  if(command instanceof sdk.TransactWriteCommand){transactions++;for(const operation of p.TransactItems){if(operation.Put){const put=operation.Put;records.set(put.TableName+'/'+put.Item.id,put.Item);}}return {};}
  throw Error('Unexpected SDK command');
 }};
 const original=sdk.DynamoDBDocumentClient.from;
 sdk.DynamoDBDocumentClient.from=()=>client;
 Object.assign(process.env,{OWNER_ID:'owner',EXPENSES_TABLE:'e',CATEGORIES_TABLE:'c',BUDGETS_TABLE:'b',METADATA_TABLE:'m',EVENTS_TABLE:'v'});
 const {handler}=require('../index');sdk.DynamoDBDocumentClient.from=original;
 const data={eventId:'expense/1/ExpenseRecorded',eventType:'ExpenseRecorded',schemaVersion:2,aggregateId:'expense',aggregateVersion:1,occurredAt:'2026-11-01T00:00:00.000Z',payload:{expenseId:'expense',amount:100,categoryId:'cat_food',spentAt:'2026-11-01T00:00:00.000Z',memo:null},deliveryState:'pending'};
 const item={ownerId:'owner',id:data.eventId,data};records.set('v/'+data.eventId,item);
 const event={Records:[{eventSource:'aws:dynamodb',eventName:'INSERT',dynamodb:{NewImage:marshall(item)}}]};
 const context={getRemainingTimeInMillis:()=>10000};
 await handler(event,context);assert.equal(records.get('v/'+data.eventId).data.deliveryState,'delivered');assert.equal(transactions,1);
 await handler(event,context);assert.equal(transactions,1);
 await handler({Records:[{...event.Records[0],eventName:'MODIFY'}]},context);assert.equal(transactions,1);
});
