'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');
const {DynamoDBClient}=require('../server/node_modules/@aws-sdk/client-dynamodb');const sdk=require('../server/node_modules/@aws-sdk/lib-dynamodb');
const {DynamoStore}=require('../server/infrastructure/dynamodb');const {migrate}=require('../server/infrastructure/migration');const {importCloud}=require('./import_cloud.cjs');
const config=JSON.parse(fs.readFileSync('/private/tmp/iris-stg-config.json'));assert.equal(config.environment,'stg');assert.ok(Object.values(config.tables).every(t=>t.endsWith('_stg')));
(async()=>{
 const client=sdk.DynamoDBDocumentClient.from(new DynamoDBClient({region:'ap-northeast-1'})),store=new DynamoStore(client,sdk,config.tables),owner=randomUUID();assert.notEqual(owner,config.owner);
 const backup={ownerId:owner,categories:[{category_id:'cat_food',name:'食費',icon_key:'restaurant',color_hex:'#F97316',sort_order:0}],expenses:[{expense_id:'legacy-expense-preserved',amount:123,category_id:'cat_food',spent_at:'2026-11-01T00:00:00.000Z',memo:'migration staging fixture'}],budgets:[{monthly_amount:10000,start_day:1,is_alert_notification_enabled:false,is_category_budget_enabled:true}],categoryBudgets:[{category_id:'cat_food',allocated_amount:1000}]};
 const original=structuredClone(backup),plan=migrate(backup,owner);let dropped=false;
 const losingClient={send:async command=>{const result=await client.send(command);if(!dropped&&command instanceof sdk.TransactWriteCommand&&command.input.TransactItems.some(x=>x.Put)){dropped=true;throw Error('injected response loss after real AWS commit');}return result;}};
 await assert.rejects(importCloud(plan,config.tables,losingClient),/injected response loss/);
 for(const table of Object.keys(config.tables))assert.equal((await store.all(owner,table)).length,0);
 assert.deepEqual(backup,original);
 const imported=await importCloud(plan,config.tables,client);assert.equal(imported.count,1);assert.equal(imported.total,123);assert.deepEqual(imported.ids,['legacy-expense-preserved']);
 const state=await store.load(owner);assert.equal(state.expenses[0].categoryId,'cat_food');assert.equal(state.budget.allocations[0].allocatedAmount,1000);
 const generation=await store.generation(owner),requestId=randomUUID(),eventId='legacy-expense-preserved/2/ExpenseChanged';
 await assert.rejects(store.commit(owner,{...state,generation:generation+1},[
  {table:'expenses',id:'legacy-expense-preserved',data:{...state.expenses[0],amount:124,version:2}},
  {table:'metadata',id:'receipt#'+requestId,data:{fixture:true}}
 ],[{eventId,eventType:'ExpenseChanged',schemaVersion:2,aggregateId:'legacy-expense-preserved',aggregateVersion:2,occurredAt:new Date().toISOString(),payload:{expenseId:'legacy-expense-preserved',amount:124,categoryId:'cat_food',spentAt:'2026-11-01T00:00:00.000Z',memo:'migration staging fixture'}}],true),{code:'VersionConflict'});
 assert.deepEqual(await store.load(owner),state);assert.equal(await store.generation(owner),generation);assert.equal(await store.get(owner,'metadata','receipt#'+requestId),null);assert.equal(await store.get(owner,'events',eventId),null);
 const result={environment:'stg',date:new Date().toISOString(),fixtureOwner:owner,rollback:{realCommittedResponseDropped:true,remainingRows:0,backupUnchanged:true},migration:{count:1,total:123,ids:imported.ids,categoryReference:'cat_food',allocation:1000},transactionFailure:{error:'VersionConflict',expenseVersion:1,amount:123,generation,receipt:null,event:null}};
 fs.writeFileSync('/private/tmp/iris-stg-migration-results.json',JSON.stringify(result,null,2)+'\n');console.log('PASS: real AWS migration, lost-response rollback, and cancelled transaction preserve state/version/generation/receipt/events');
})().catch(error=>{console.error(error);process.exitCode=1;});
