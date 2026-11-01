'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');const c=JSON.parse(fs.readFileSync('/private/tmp/iris-stg-config.json'));assert.equal(c.environment,'stg');
async function invoke(path,operation,input){const r=await fetch(c.endpoint.replace(/\/$/,'')+path,{method:'POST',headers:{'content-type':'application/json','x-user-id':c.owner},body:JSON.stringify({schemaVersion:3,operation,input,...(path==='/commands'?{requestId:randomUUID()}:{})})});const body=await r.json();assert.equal(r.status,200,JSON.stringify(body));return body;}
const command=(op,input)=>invoke('/commands',op,input),query=(op,input={})=>invoke('/queries',op,input);
(async()=>{
 const original=(await query('GetBudgetPlan')).value;let result;
 try{
  await command('ConfigureBudgetPlan',{...original,version:undefined,expectedVersion:original.version,monthlyAmount:1000,startDay:1,allocations:[],notificationEnabled:true});
  await command('RecordExpense',{id:randomUUID(),amount:1000,categoryId:'cat_food',spentAt:'2086-08-01T03:00:00.000Z',paymentMethod:'cash',memo:'stg notification thresholds'});
  const three=(await query('CalculateBudgetSummary',{asOfDate:'2086-08-03',timeZone:'Asia/Tokyo'})).value,four=(await query('CalculateBudgetSummary',{asOfDate:'2086-08-04',timeZone:'Asia/Tokyo'})).value;assert.equal(three.isProjectedToOverspend,false);assert.equal(four.isProjectedToOverspend,true);
  const decision=await command('EvaluateBudgetThresholds',{asOfDate:'2086-08-04',timeZone:'Asia/Tokyo'});assert.deepEqual(decision.value.map(x=>x.threshold),[80,100]);assert.ok(decision.value.every(x=>x.shouldNotify));const again=await command('EvaluateBudgetThresholds',{asOfDate:'2086-08-04',timeZone:'Asia/Tokyo'});assert.deepEqual(again.value,[]);assert.equal(decision.readGeneration,again.readGeneration);
  result={environment:'stg',date:new Date().toISOString(),thresholds:[80,100],shouldNotify:[true,true],secondEvaluation:[],day3Warning:false,day4Warning:true,generationUnchangedOnReceipt:true};
 } finally {const current=(await query('GetBudgetPlan')).value;const {version,...input}=original;await command('ConfigureBudgetPlan',{...input,expectedVersion:current.version});}
 fs.writeFileSync('/private/tmp/iris-stg-budget-notifications.json',JSON.stringify(result,null,2)+'\n');console.log('PASS: ON 80/100 once, repeated evaluation empty, three-day forecast warning guard');
})().catch(error=>{console.error(error);process.exitCode=1;});
