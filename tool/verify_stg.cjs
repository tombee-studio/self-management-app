'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');const {performance}=require('node:perf_hooks');
const {DynamoDBClient}=require('../server/node_modules/@aws-sdk/client-dynamodb');
const sdk=require('../server/node_modules/@aws-sdk/lib-dynamodb');
const {validate}=require('../server/api/schema');const {Tokens}=require('../server/infrastructure/tokens');
const {DynamoStore}=require('../server/infrastructure/dynamodb');
const config=JSON.parse(fs.readFileSync(process.argv[2]||'/private/tmp/iris-stg-config.json','utf8'));
assert.equal(config.environment,'stg');assert.ok(Object.values(config.tables).every(x=>x.includes('_stg')));
const client=sdk.DynamoDBDocumentClient.from(new DynamoDBClient({region:'ap-northeast-1'}));const store=new DynamoStore(client,sdk,config.tables);
const results=[];const run=randomUUID().slice(0,8);const samples=[];
async function check(name,fn){const start=performance.now();try{const measured=await fn();results.push({name,status:'PASS',milliseconds:Math.round(performance.now()-start),measured});console.log('PASS '+name);}catch(error){results.push({name,status:'FAIL',error:error.message});throw error;}}
async function call(path,body,{status=200,owner=config.owner,method='POST'}={}){
 const started=performance.now();const url=config.endpoint.replace(/\/$/,'')+path;
 const response=await fetch(method==='GET'&&path==='/payment'?url+'?'+new URLSearchParams(body):url,{method,headers:{'content-type':'application/json','x-user-id':owner},...(method==='POST'?{body:JSON.stringify(body)}:{})});
 const json=await response.json();samples.push({path,operation:body?.operation,status:response.status,milliseconds:Math.round(performance.now()-started)});
 if(Array.isArray(status))assert.ok(status.includes(response.status),JSON.stringify(json));else assert.equal(response.status,status,JSON.stringify(json));
 validate(json,response.status===200?(path==='/commands'?'CommandResponse':path==='/queries'?'QueryResponse':path==='/payment'?'PaymentResponse':'HealthResponse'):'Error');return json;
}
const command=(operation,input,options={})=>call('/commands',{schemaVersion:3,operation,input,requestId:options.requestId||randomUUID()},options);
const query=(operation,input={},options={})=>call('/queries',{schemaVersion:3,operation,input},options);
const expense=(changes={})=>({id:randomUUID(),amount:1280,categoryId:'cat_food',spentAt:'2026-11-01T03:00:00.000Z',paymentMethod:'cash',memo:'STG '+run,...changes});
const filter=month=>({month,keyword:'',categoryIds:[],source:null,timeZone:'Asia/Tokyo'});
async function totals(f){const p=await query('QueryHistory',{filter:f});return (await query('GetHistoryTotals',{filter:f,snapshotId:p.value.snapshotId})).value;}
async function main(){
 await check('health / schemaVersion / owner / removed sync routes',async()=>{
  await call('/health',{}, {method:'GET'});await call('/queries',{schemaVersion:2,operation:'GetCatalog',input:{}},{status:400});await call('/queries',{schemaVersion:3,operation:'GetCatalog',input:{}},{owner:'wrong-owner',status:403});
  const r=await fetch(config.endpoint.replace(/\/$/,'')+'/sync/push',{method:'POST'});assert.equal(r.status,404);return {health:200,unsupportedVersion:400,ownerMismatch:403,legacy:404};
 });
 await check('initial catalog 9 / idempotent seed / unset plan 404',async()=>{
  const a=await command('EnsureDefaultCatalog',{});const before=await store.generation(config.owner);await command('EnsureDefaultCatalog',{});assert.equal(await store.generation(config.owner),before);assert.equal(a.value.categories.length,9);await query('GetBudgetPlan',{}, {status:404});return {categories:9};
 });
 let recorded;
 await check('Record / same request replay / different input / persisted receipt and event',async()=>{
  const input=expense({memo:'  STG\n入力  '}),requestId=randomUUID();const a=await command('RecordExpense',input,{requestId});const generation=await store.generation(config.owner);
  assert.deepEqual(await command('RecordExpense',input,{requestId}),a);assert.equal(await store.generation(config.owner),generation);await command('RecordExpense',{...input,amount:1},{requestId,status:409});
  recorded=a.value;assert.equal(recorded.memo,'STG 入力');assert.equal((await store.get(config.owner,'metadata','receipt#'+requestId)).response.value.id,input.id);assert.ok(await store.get(config.owner,'events',input.id+'/1/ExpenseRecorded'));return {id:input.id,version:1,memo:recorded.memo,generation};
 });
 await check('invalid money / category / dates / grapheme / extra attributes leave ledger unchanged',async()=>{
  const before=await store.generation(config.owner);
  for(const amount of [0,-1,100000000,1.5])await command('RecordExpense',expense({amount}),{status:400});
  await command('RecordExpense',expense({categoryId:'missing'}),{status:404});await command('RecordExpense',expense({spentAt:'1969-12-31T23:59:59.999Z'}),{status:400});await command('RecordExpense',expense({spentAt:'2026-02-30T00:00:00.000Z'}),{status:400});
  await command('RecordExpense',expense({memo:'👨‍👩‍👧'.repeat(101)}),{status:400});await call('/queries',{schemaVersion:3,operation:'GetCatalog',input:{},extra:1},{status:400});assert.equal(await store.generation(config.owner),before);return {unchangedGeneration:before};
 });
 await check('parallel stale-version modifications commit exactly once',async()=>{
  const before=await store.generation(config.owner);const send=amount=>fetch(config.endpoint.replace(/\/$/,'')+'/commands',{method:'POST',headers:{'content-type':'application/json','x-user-id':config.owner},body:JSON.stringify({schemaVersion:3,requestId:randomUUID(),operation:'ModifyExpense',input:{id:recorded.id,expectedVersion:1,changes:{amount}}})});
  const responses=await Promise.all([send(1400),send(1500)]);assert.deepEqual(responses.map(r=>r.status).sort(),[200,409]);recorded=(await query('GetExpense',{id:recorded.id})).value;assert.equal(recorded.version,2);assert.equal(await store.generation(config.owner),before+1);return {statuses:[200,409],version:2};
 });
 await check('swipe delete / restore same identity / expired grant / explicit no grant',async()=>{
  const d=await command('DeleteExpense',{id:recorded.id,expectedVersion:2,kind:'swipe'});await query('GetExpense',{id:recorded.id},{status:404});const restored=await command('RestoreExpense',{grant:d.value.undoGrant});assert.equal(restored.value.id,recorded.id);assert.equal(restored.value.amount,recorded.amount);
  const requestId=randomUUID();const deleted=await command('DeleteExpense',{id:recorded.id,expectedVersion:4,kind:'swipe'});
  const raw=await store.get(config.owner,'metadata','undo#'+deleted.value.undoGrant);await client.send(new sdk.PutCommand({TableName:config.tables.metadata,Item:{ownerId:config.owner,id:'undo#'+deleted.value.undoGrant,data:{...raw,deletedAt:new Date(Date.now()-31000).toISOString()}}}));
  await command('RestoreExpense',{grant:deleted.value.undoGrant},{requestId,status:410});return {restoredVersion:restored.value.version,expired:410};
 });
 await check('payment POST/GET / currency and timestamps / external and 180-second dedup',async()=>{
  const p={requestId:randomUUID(),amount:'¥1,280',merchant:'セブン STG '+run,external_tx_id:'stg-'+run};const a=await call('/payment',p);assert.deepEqual(await call('/payment',p),a);assert.equal((await call('/payment',{...p,requestId:randomUUID()})).status,'duplicate');
  const raw={requestId:randomUUID(),amount:'200',merchant:'境界 '+run,spent_at:'2036-01-01T00:00:00Z'};await call('/payment',raw,{method:'GET'});assert.equal((await call('/payment',{...raw,requestId:randomUUID(),spent_at:'2036-01-01T00:03:00Z'})).status,'duplicate');assert.equal((await call('/payment',{...raw,requestId:randomUUID(),spent_at:'2036-01-01T00:03:01Z'})).status,'created');
  await call('/payment',{requestId:randomUUID(),amount:'1+2'},{status:400});await call('/payment',{requestId:randomUUID(),amount:10,currency:'USD'},{status:400});await call('/payment',{requestId:randomUUID(),amount:10,spent_at:'bad'},{status:400});
  const e=(await query('GetExpense',{id:a.expense_id})).value;assert.equal(e.categoryId,'cat_food');assert.equal(e.source,'apple_pay');return {normalizedAmount:e.amount,externalReplay:'duplicate',seconds180:'duplicate',seconds181:'created'};
 });
 let category;
 await check('category name normalization / protected uncategorized / reorder / configure plan',async()=>{
  let c=(await query('GetCatalog')).value;category=randomUUID();const created=await command('UpsertCategory',{categoryId:category,expectedCatalogVersion:c.version,name:'ＡＢＣ'+run,iconKey:'folder',colorHex:'#6366F1'});c=created.value;
  await command('UpsertCategory',{categoryId:randomUUID(),expectedCatalogVersion:c.version,name:'abc'+run,iconKey:'folder',colorHex:'#6366F1'},{status:400});await command('RetireCategory',{categoryId:'cat_uncategorized',expectedCatalogVersion:c.version},{status:400});
  const reordered=await command('ReorderCatalog',{expectedCatalogVersion:c.version,orderedIds:c.categories.map(x=>x.id).reverse()});assert.equal(reordered.value.categories[0].id,category);
  await command('ConfigureBudgetPlan',{expectedVersion:0,monthlyAmount:100000,startDay:1,allocations:[{categoryId:category,allocatedAmount:10000}],notificationEnabled:false,categoryBudgetEnabled:true});return {category,version:reordered.value.version};
 });
 await check('1000-fixture category retirement / concurrent save / atomic allocation and read resolution',async()=>{
  const rows=Array.from({length:1000},()=>{const e={...expense({amount:100,categoryId:category,spentAt:'1999-01-01T00:00:00.000Z'}),source:'manual',externalTxId:null,version:1,isDeleted:false};return {ownerId:config.owner,id:e.id,data:e};});
  for(let n=0;n<rows.length;n+=25){let pending=rows.slice(n,n+25).map(Item=>({PutRequest:{Item}}));while(pending.length){const r=await client.send(new sdk.BatchWriteCommand({RequestItems:{[config.tables.expenses]:pending}}));pending=r.UnprocessedItems?.[config.tables.expenses]||[];}}
  await client.send(new sdk.UpdateCommand({TableName:config.tables.metadata,Key:{ownerId:config.owner,id:'generation'},UpdateExpression:'SET #d.#v = #d.#v + :one',ExpressionAttributeNames:{'#d':'data','#v':'value'},ExpressionAttributeValues:{':one':1}}));
  const before=await totals(filter('1999-01'));const c=(await query('GetCatalog')).value;
  const [retirement,parallel]=await Promise.all([command('RetireCategory',{categoryId:category,expectedCatalogVersion:c.version}),command('RecordExpense',expense({amount:20,categoryId:category,spentAt:'1999-01-01T00:00:00.000Z'}),{status:[200,404]})]);const added=parallel.value?1:0;assert.equal(retirement.value.movedExpenseCount,1000+added);assert.equal((await totals(filter('1999-01'))).total,before.total+added*20);assert.equal((await query('GetExpense',{id:rows[0].id})).value.categoryId,'cat_uncategorized');assert.equal((await store.get(config.owner,'expenses',rows[0].id)).categoryId,category);assert.equal((await query('GetBudgetPlan')).value.allocations.length,0);return {count:1000+added,total:before.total+added*20,physicalExpenseRewrites:0,concurrentSave:added?200:404};
 });
 await check('121 history rows / 50-50-21 / stable totals / Unicode and literal AND-OR search / invalid cursors',async()=>{
  for(let n=0;n<121;n++)await command('RecordExpense',expense({amount:100,spentAt:'2035-02-01T00:00:00.000Z',categoryId:n%2?'cat_daily':'cat_food',memo:n%2?'Other':'ＡＢＣ [x]'}));
  const f=filter('2035-02'),one=await query('QueryHistory',{filter:f}),two=await query('QueryHistory',{filter:f,cursor:one.value.nextCursor}),three=await query('QueryHistory',{filter:f,cursor:two.value.nextCursor});assert.deepEqual([one.value.items.length,two.value.items.length,three.value.items.length],[50,50,21]);assert.equal(new Set([...one.value.items,...two.value.items,...three.value.items].map(x=>x.id)).size,121);assert.equal((await totals(f)).total,12100);
  const t=await totals({...f,keyword:'abc [x]',categoryIds:['cat_food','cat_daily'],source:'manual'});assert.equal(t.total,6100);assert.equal(t.monthTotal,12100);
  await query('QueryHistory',{filter:f,cursor:one.value.nextCursor+'x'},{status:409});await query('QueryHistory',{filter:{...f,keyword:'different'},cursor:one.value.nextCursor},{status:409});
  const secret=fs.readFileSync('terraform/environments/stg/secrets.auto.tfvars','utf8').match(/cursor_secret\s*=\s*"([^"]+)"/)[1];const expired=new Tokens(secret,()=>Date.now()-1000000).sign({owner:config.owner,generation:one.readGeneration,filter:new Tokens(secret).hash(f),timeZone:f.timeZone});await query('QueryHistory',{filter:f,cursor:expired},{status:409});
  await command('RecordExpense',expense({spentAt:'2035-03-01T00:00:00.000Z'}));await query('QueryHistory',{filter:f,cursor:one.value.nextCursor},{status:409});return {pages:[50,50,21],total:12100,searchTotal:6100};
 });
 await check('budget calendar period / future expenses / three-day forecast / OFF threshold receipts',async()=>{
  const p=(await query('GetBudgetPlan')).value;await command('ConfigureBudgetPlan',{expectedVersion:p.version,monthlyAmount:1000,startDay:25,allocations:[],notificationEnabled:false,categoryBudgetEnabled:false});
  await command('RecordExpense',expense({amount:1000,spentAt:'2099-11-20T12:00:00.000Z'}));const summary=(await query('CalculateBudgetSummary',{asOfDate:'2099-11-01',timeZone:'America/New_York'})).value;assert.equal(summary.periodStart,'2099-10-25');assert.equal(summary.daysTotal,31);assert.equal(summary.daysRemaining,24);assert.equal(summary.totalSpent,1000);const before=await store.generation(config.owner);
  const decisions=await command('EvaluateBudgetThresholds',{asOfDate:'2099-11-01',timeZone:'Asia/Tokyo'});assert.deepEqual(decisions.value.map(x=>x.threshold),[80,100]);assert.ok(decisions.value.every(x=>!x.shouldNotify));assert.deepEqual((await command('EvaluateBudgetThresholds',{asOfDate:'2099-11-01',timeZone:'Asia/Tokyo'})).value,[]);assert.equal(await store.generation(config.owner),before);return summary;
 });
 await check('catalog capacity 150KiB guard leaves generation and stored aggregate unchanged',async()=>{
  const original=await store.get(config.owner,'categories','catalog');const large={...original,categories:[...original.categories,...Array.from({length:1100},(_,n)=>({id:randomUUID(),name:'容量'+n,nameKey:'容量'+n,iconKey:'folder',colorHex:'#6366F1',isSystem:false,sortOrder:n+10}))]};
  assert.ok(Buffer.byteLength(JSON.stringify(large))>150*1024);await client.send(new sdk.PutCommand({TableName:config.tables.categories,Item:{ownerId:config.owner,id:'catalog',data:large}}));const generation=await store.generation(config.owner);
  try {await command('UpsertCategory',{categoryId:randomUUID(),expectedCatalogVersion:large.version,name:'容量超過',iconKey:'folder',colorHex:'#6366F1'},{status:413});assert.equal(await store.generation(config.owner),generation);assert.deepEqual(await store.get(config.owner,'categories','catalog'),large);}finally{await client.send(new sdk.PutCommand({TableName:config.tables.categories,Item:{ownerId:config.owner,id:'catalog',data:original}}));}
  return {bytes:Buffer.byteLength(JSON.stringify(large)),status:413,unchangedGeneration:generation};
 });
 await check('DynamoDB Streams event delivery / per-event consumer receipt',async()=>{
  let events=[];
  for(let n=0;n<40;n++){events=await store.all(config.owner,'events');if(events.every(e=>e.deliveryState==='delivered'))break;await new Promise(r=>setTimeout(r,1000));}
  const pending=events.filter(e=>e.deliveryState!=='delivered');assert.equal(pending.length,0);for(const event of events)assert.ok(await store.get(config.owner,'metadata','event-consumer#commit-audit#'+event.eventId));return {events:events.length,delivered:events.length,pending:0};
 });
 // Leave a readable, non-notifying budget for the simulator scenario.
 const plan=(await query('GetBudgetPlan')).value;await command('ConfigureBudgetPlan',{expectedVersion:plan.version,monthlyAmount:100000,startDay:1,allocations:[],notificationEnabled:false,categoryBudgetEnabled:false});
}
main().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>{
 const report={run,date:new Date().toISOString(),environment:'stg',endpoint:config.endpoint,owner:config.owner,results,requests:samples};
 fs.writeFileSync('/private/tmp/iris-stg-provider-results.json',JSON.stringify(report,null,2)+'\n');console.log('Result: '+results.filter(r=>r.status==='PASS').length+'/'+results.length);
});
