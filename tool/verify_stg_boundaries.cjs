'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');const {validate}=require('../server/api/schema');
const c=JSON.parse(fs.readFileSync('/private/tmp/iris-stg-config.json'));assert.equal(c.environment,'stg');const results=[];
async function command(operation,input,status=200,requestId=randomUUID()){
 const response=await fetch(c.endpoint.replace(/\/$/,'')+'/commands',{method:'POST',headers:{'content-type':'application/json','x-user-id':c.owner},body:JSON.stringify({schemaVersion:3,operation,input,requestId})});const data=await response.json();assert.equal(response.status,status,JSON.stringify(data));validate(data,status===200?'CommandResponse':'Error');return data;
}
async function query(operation,input={}){const r=await fetch(c.endpoint.replace(/\/$/,'')+'/queries',{method:'POST',headers:{'content-type':'application/json','x-user-id':c.owner},body:JSON.stringify({schemaVersion:3,operation,input})});assert.equal(r.status,200);return (await r.json()).value;}
const e=changes=>({id:randomUUID(),amount:1,categoryId:'cat_uncategorized',spentAt:'2050-01-01T00:00:00.000Z',paymentMethod:'cash',memo:null,...changes});
async function check(name,fn){const result=await fn();results.push({name,status:'PASS',measured:result});console.log('PASS '+name);}
(async()=>{
 await check('inclusive JPY/date/grapheme boundaries and explicit deletion without Undo',async()=>{
  const min=await command('RecordExpense',e({spentAt:'1970-01-01T00:00:00.000Z'}));const max=await command('RecordExpense',e({amount:99999999,memo:'👨‍👩‍👧'.repeat(100)}));assert.equal(max.value.amount,99999999);assert.equal(min.value.amount,1);
  const requestId=randomUUID(),input={id:max.value.id,expectedVersion:1,kind:'explicit'};const removed=await command('DeleteExpense',input,200,requestId);assert.equal(removed.value.undoGrant,null);assert.deepEqual(await command('DeleteExpense',input,200,requestId),removed);await command('RestoreExpense',{grant:'nonexistent'},410);return {min:1,max:99999999,epochAccepted:true,graphemes:100,explicitUndo:null};
 });
 await check('category name/icon/color/order negative boundaries preserve catalog version',async()=>{
  const catalog=await query('GetCatalog');const base={categoryId:randomUUID(),expectedCatalogVersion:catalog.version,name:'境界',iconKey:'folder',colorHex:'#6366F1'};
  for(const change of [{name:''},{name:' '},{name:'界'.repeat(21)},{iconKey:'not-allowed'},{colorHex:'#123'}])await command('UpsertCategory',{...base,...change},400);
  await command('UpsertCategory',{...base,categoryId:'cat_uncategorized'},400);await command('ReorderCatalog',{expectedCatalogVersion:catalog.version,orderedIds:[catalog.categories[0].id,catalog.categories[0].id]},400);assert.equal((await query('GetCatalog')).version,catalog.version);return {catalogVersionUnchanged:catalog.version};
 });
 await check('budget invalid money/start/allocation/duplicates reject atomically',async()=>{
  const plan=await query('GetBudgetPlan');const base={expectedVersion:plan.version,monthlyAmount:100000,startDay:1,allocations:[],notificationEnabled:false,categoryBudgetEnabled:false};
  for(const change of [{monthlyAmount:0},{monthlyAmount:100000000},{startDay:0},{startDay:29},{allocations:[{categoryId:'cat_food',allocatedAmount:-1}]},{allocations:[{categoryId:'cat_food',allocatedAmount:1},{categoryId:'cat_food',allocatedAmount:2}]}])await command('ConfigureBudgetPlan',{...base,...change},400);
  assert.deepEqual(await query('GetBudgetPlan'),plan);return {planVersionUnchanged:plan.version};
 });
 fs.writeFileSync('/private/tmp/iris-stg-boundary-results.json',JSON.stringify({environment:'stg',date:new Date().toISOString(),results},null,2)+'\n');
})().catch(error=>{console.error(error);process.exitCode=1;});
