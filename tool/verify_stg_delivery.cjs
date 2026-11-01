'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');
const {DynamoDBClient}=require('../server/node_modules/@aws-sdk/client-dynamodb');const sdk=require('../server/node_modules/@aws-sdk/lib-dynamodb');const {DynamoStore}=require('../server/infrastructure/dynamodb');
const config=JSON.parse(fs.readFileSync('/private/tmp/iris-stg-config.json'));assert.equal(config.environment,'stg');const started=new Date().toISOString();
const store=new DynamoStore(sdk.DynamoDBDocumentClient.from(new DynamoDBClient({region:'ap-northeast-1'})),sdk,config.tables);
(async()=>{
 const ids=[];const durations=[];
 for(let n=0;n<30;n++){
  const id=randomUUID();ids.push(id);const start=Date.now();const response=await fetch(config.endpoint.replace(/\/$/,'')+'/commands',{method:'POST',headers:{'content-type':'application/json','x-user-id':config.owner},body:JSON.stringify({schemaVersion:3,operation:'RecordExpense',requestId:randomUUID(),input:{id,amount:10,categoryId:'cat_food',spentAt:'2020-01-01T00:00:00.000Z',paymentMethod:'cash',memo:'stg event contention regression'}})});assert.equal(response.status,200,await response.text());durations.push(Date.now()-start);
 }
 let pending=[];
 for(let n=0;n<45;n++){
  pending=[];
  for(const id of ids){const event=await store.get(config.owner,'events',id+'/1/ExpenseRecorded');if(event?.deliveryState!=='delivered')pending.push(id);}
  if(!pending.length)break;await new Promise(resolve=>setTimeout(resolve,1000));
 }
 assert.equal(pending.length,0);
 for(const id of ids)assert.ok(await store.get(config.owner,'metadata','event-consumer#commit-audit#'+id+'/1/ExpenseRecorded'));
 const result={environment:'stg',started,finished:new Date().toISOString(),writes:30,delivered:30,pending:0,durationsMs:durations,receiptCount:30};fs.writeFileSync('/private/tmp/iris-stg-delivery-results.json',JSON.stringify(result,null,2)+'\n');console.log('PASS: 30 ledger writes and 30 event receipts delivered without ledger-generation coupling');
})().catch(error=>{console.error(error);process.exitCode=1;});
