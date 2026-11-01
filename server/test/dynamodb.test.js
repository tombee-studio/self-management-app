'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');const {DynamoStore}=require('../infrastructure/dynamodb');const {Service}=require('../application/service');const {Tokens}=require('../infrastructure/tokens');const {randomUUID}=require('node:crypto');
class GetCommand{constructor(input){this.input=input;}}
class QueryCommand extends GetCommand{}class TransactWriteCommand extends GetCommand{}
const commands={GetCommand,QueryCommand,TransactWriteCommand};const tables={expenses:'e',categories:'c',budgets:'b',metadata:'m',events:'events'};
function fixture(){const requests=[];const items=new Map();const client={send:async command=>{
 requests.push(command);
 const p=command.input;
 if(command instanceof TransactWriteCommand){
  for(const op of p.TransactItems){const v=op.Put||op.ConditionCheck,key=v.Item||v.Key,old=items.get(v.TableName+'/'+key.ownerId+'/'+key.id);
   if(v.ConditionExpression==='attribute_not_exists(ownerId)'&&old||v.ConditionExpression==='#d.#v = :v'&&old?.data[v.ExpressionAttributeNames['#v']]!==v.ExpressionAttributeValues[':v']){const e=Error();e.name='TransactionCanceledException';throw e;}
  }
  for(const op of p.TransactItems){if(op.Put){const p=op.Put;items.set(p.TableName+'/'+p.Item.ownerId+'/'+p.Item.id,p.Item);}}
  return {};
 }
 if(command instanceof QueryCommand)return {Items:[...items].filter(([k])=>k.startsWith(p.TableName+'/'+p.ExpressionAttributeValues[':owner']+'/')).map(([,v])=>v)};
 return {Item:items.get(p.TableName+'/'+p.Key.ownerId+'/'+p.Key.id)};
 }};const store=new DynamoStore(client,commands,tables);const service=new Service({store,tokens:new Tokens('provider-test-at-least-thirty-two-characters'),uuid:randomUUID,clock:()=> '2026-11-01T03:00:00.000Z'});
 return {requests,items,store,service,command:(operation,input)=>service.command('owner',{operation,input,requestId:randomUUID()})};}
test('provider puts generation, aggregate, receipt and events in one conditional transaction',async()=>{
 const f=fixture();await f.command('EnsureDefaultCatalog',{});
 const tx=f.requests.find(x=>x instanceof TransactWriteCommand).input.TransactItems;
 assert.equal(tx.length,4);assert.ok(tx.every(x=>x.Put.ConditionExpression==='attribute_not_exists(ownerId)'));assert.equal(f.items.size,4);
 await f.command('RecordExpense',{id:randomUUID(),amount:100,categoryId:'cat_food',spentAt:'2026-11-01T03:00:00.000Z',memo:null,paymentMethod:'cash'});
 const last=f.requests.filter(x=>x instanceof TransactWriteCommand).at(-1).input.TransactItems;
 assert.ok(last.some(x=>x.ConditionCheck?.TableName==='c'));assert.ok(last.some(x=>x.Put?.ConditionExpression==='#d.#v = :v'));
 assert.ok(f.requests.filter(x=>x instanceof GetCommand&&!(x instanceof TransactWriteCommand)).every(x=>x.input.ConsistentRead===true));
});
test('retirement transaction stays fixed for 1000 items, protects budget and catalog and never rewrites expenses',async()=>{
 const f=fixture();await f.command('EnsureDefaultCatalog',{});await f.command('ConfigureBudgetPlan',{expectedVersion:0,monthlyAmount:10000,startDay:1,notificationEnabled:true,categoryBudgetEnabled:true,allocations:[{categoryId:'cat_food',allocatedAmount:1000}]});
 for(let n=0;n<1000;n++)f.items.set('e/owner/'+n,{ownerId:'owner',id:String(n),data:{id:String(n),amount:100,categoryId:'cat_food',spentAt:'2026-11-01T03:00:00.000Z',memo:null,paymentMethod:'cash',source:'manual',externalTxId:null,version:1,isDeleted:false}});
 await f.command('RetireCategory',{categoryId:'cat_food',expectedCatalogVersion:1});
 const tx=f.requests.filter(x=>x instanceof TransactWriteCommand).at(-1).input.TransactItems;
 assert.ok(tx.length<=20);assert.ok(Buffer.byteLength(JSON.stringify(tx))<1024*1024);assert.ok(tx.every(x=>(x.Put||x.ConditionCheck).TableName!=='e'));assert.equal(tx.filter(x=>x.Put?.TableName==='c'||x.Put?.TableName==='b').length,2);
 assert.equal(f.items.get('e/owner/1').data.categoryId,'cat_food');
});
test('provider rejects catalog/plan over 150KiB without issuing a transaction',async()=>{
 const f=fixture();const snapshot={generation:0,catalog:null,budget:null,expenses:[]};
 for(const table of ['categories','budgets'])await assert.rejects(f.store.commit('owner',snapshot,[{table,id:'large',data:{padding:'x'.repeat(151*1024)}}],[],true),{code:'PayloadTooLarge'});
 assert.equal(f.requests.length,0);
});
test('provider traverses every strongly consistent Query page and honors deadline',async()=>{
 let page=0;const sent=[];const store=new DynamoStore({send:async c=>{sent.push(c.input);return ++page<3?{Items:[{data:page}],LastEvaluatedKey:{ownerId:'owner',id:String(page)}}:{Items:[{data:page}]};}},commands,tables);
 assert.deepEqual(await store.all('owner','expenses'),[1,2,3]);assert.ok(sent.every(x=>x.ConsistentRead));assert.deepEqual(sent[1].ExclusiveStartKey,{ownerId:'owner',id:'1'});
 store.deadline=()=>true;await assert.rejects(store.all('owner','expenses'),{code:'Busy'});
});
test('event delivery is atomic and does not read or CAS unrelated ledger/catalog state',async()=>{
 const f=fixture();await f.store.deliver('owner','event-consumer#c#e',{eventId:'e',schemaVersion:2,deliveryState:'pending'},[{table:'metadata',id:'effect#e',data:{done:true}}]);
 assert.equal(f.requests.length,1);const tx=f.requests[0].input.TransactItems;
 assert.equal(tx.length,3);assert.ok(tx.every(x=>!x.ConditionCheck));assert.ok(tx.every(x=>x.Put.Item.id!=='generation'&&x.Put.Item.id!=='catalog'));assert.equal(tx[1].Put.ConditionExpression,'attribute_not_exists(ownerId)');
});
