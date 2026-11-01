'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');
const {Service}=require('../application/service');const {Tokens}=require('../infrastructure/tokens');const {createHandler}=require('../api/handler');
const {validate,matches}=require('../api/schema');const schema=require('../contracts/shared.schema.json');const D=require('../domain/model');const {MemoryStore}=require('./support');
const owner='test-owner';const date='2026-11-01T03:00:00.000Z';
async function fixture(){
 const store=new MemoryStore();let clock=Date.parse(date);const tokens=new Tokens('test-secret-with-at-least-32-characters',()=>clock);
 const service=new Service({store,tokens,clock:()=>new Date(clock).toISOString(),uuid:randomUUID});
 const handler=createHandler(service,owner);
 const command=(operation,input,requestId=randomUUID())=>service.command(owner,{operation,input,requestId});
 const query=(operation,input={})=>service.query(owner,{operation,input});
 await command('EnsureDefaultCatalog',{});
 return {store,service,tokens,handler,command,query,advance:ms=>clock+=ms};
}
const input=(id=randomUUID(),amount=100)=>({id,amount,categoryId:'cat_food',spentAt:date,paymentMethod:'cash',memo:null});
const filter={month:'2026-11',keyword:'',categoryIds:[],source:null,timeZone:'Asia/Tokyo'};
test('commands enforce money, normalization, versions, immutable origin, rollback and receipts',async()=>{
 const f=await fixture();const id=randomUUID(),requestId=randomUUID(),i=input(id);
 const r=await f.command('RecordExpense',i,requestId);validate(r,'CommandResponse');assert.equal(r.value.version,1);
 const generation=await f.store.generation(owner),events=f.store.tables.events.size;
 assert.deepEqual(await f.command('RecordExpense',i,requestId),r);assert.equal(await f.store.generation(owner),generation);assert.equal(f.store.tables.events.size,events);
 await assert.rejects(f.command('RecordExpense',{...i,amount:101},requestId),{code:'VersionConflict'});
 await assert.rejects(f.command('ModifyExpense',{id,expectedVersion:2,changes:{amount:200}}),{code:'VersionConflict'});
 for(const amount of [0,-1,100000000,1.5])await assert.rejects(f.command('RecordExpense',input(randomUUID(),amount)),{code:'ValidationFailed'});
 const m=await f.command('ModifyExpense',{id,expectedVersion:1,changes:{memo:'  hello\nworld  ',amount:200}});
 assert.equal(m.value.memo,'hello world');assert.equal(m.value.source,'manual');assert.equal(m.value.version,2);
 const before=structuredClone(f.store.tables);f.store.beforeCommit=()=>{throw Error('storage unavailable');};
 await assert.rejects(f.command('ModifyExpense',{id,expectedVersion:2,changes:{amount:500}}));assert.deepEqual(f.store.tables,before);
 f.store.beforeCommit=null;
});
test('commit followed by lost response replays original response without duplicate state',async()=>{
 const f=await fixture(),id=randomUUID(),requestId=randomUUID(),i=input(id);
 f.store.afterCommit=()=>{throw Error('lost response');};await assert.rejects(f.command('RecordExpense',i,requestId));
 f.store.afterCommit=null;const generation=await f.store.generation(owner),events=f.store.tables.events.size;
 const r=await f.command('RecordExpense',i,requestId);assert.equal(r.value.id,id);assert.equal(await f.store.generation(owner),generation);assert.equal(f.store.tables.events.size,events);
});
test('Undo uses commit deadline, same ID/content, single grant, and receipt before expiry',async()=>{
 const f=await fixture();const e=await f.command('RecordExpense',input());
 const d=await f.command('DeleteExpense',{id:e.value.id,expectedVersion:1,kind:'swipe'});const requestId=randomUUID();
 f.advance(29900);const r=await f.command('RestoreExpense',{grant:d.value.undoGrant},requestId);assert.equal(r.value.id,e.value.id);assert.equal(r.value.amount,100);assert.equal(r.value.version,3);
 f.advance(10000);assert.deepEqual(await f.command('RestoreExpense',{grant:d.value.undoGrant},requestId),r);
 const d2=await f.command('DeleteExpense',{id:e.value.id,expectedVersion:3,kind:'swipe'});f.advance(30000);await assert.rejects(f.command('RestoreExpense',{grant:d2.value.undoGrant}),{code:'UndoExpired'});
 await assert.rejects(f.query('GetExpense',{id:e.value.id}),{code:'NotFound'});
 const explicit=await f.command('RecordExpense',input());const deleted=await f.command('DeleteExpense',{id:explicit.value.id,expectedVersion:1,kind:'explicit'});assert.equal(deleted.value.undoGrant,null);
});
test('catalog uniqueness, protected default, complete reorder and retirement of 1000 expenses with budget',async()=>{
 const f=await fixture();const c=await f.query('GetCatalog');assert.equal(c.value.categories.length,9);
 const id=randomUUID();const custom=await f.command('UpsertCategory',{categoryId:id,expectedCatalogVersion:1,name:'ＡＢＣ',iconKey:'folder',colorHex:'#123456'});
 await assert.rejects(f.command('UpsertCategory',{categoryId:randomUUID(),expectedCatalogVersion:2,name:'abc',iconKey:'folder',colorHex:'#123456'}),{code:'InvariantViolation'});
 await assert.rejects(f.command('RetireCategory',{categoryId:'cat_uncategorized',expectedCatalogVersion:2}),{code:'InvariantViolation'});
 await assert.rejects(f.command('ReorderCatalog',{expectedCatalogVersion:2,orderedIds:[id]}),{code:'ValidationFailed'});
 const reordered=await f.command('ReorderCatalog',{expectedCatalogVersion:2,orderedIds:custom.value.categories.map(x=>x.id).reverse()});assert.equal(reordered.value.version,3);
 await f.command('ConfigureBudgetPlan',{expectedVersion:0,monthlyAmount:1000,startDay:1,notificationEnabled:true,categoryBudgetEnabled:true,allocations:[{categoryId:id,allocatedAmount:500}]});
 for(let n=0;n<1000;n++)f.store.tables.expenses.set(owner+'/'+n,{...input(String(n)),categoryId:id,source:'manual',externalTxId:null,version:1,isDeleted:false});
 const r=await f.command('RetireCategory',{categoryId:id,expectedCatalogVersion:3});assert.equal(r.value.movedExpenseCount,1000);
 assert.equal((await f.query('GetBudgetPlan')).value.allocations.length,0);
 assert.equal((await f.query('GetExpense',{id:'1'})).value.categoryId,'cat_uncategorized');assert.equal((await f.query('WatchDailySummary',{date:'2026-11-01',timeZone:'Asia/Tokyo'})).value.total,100000);
 const unchanged=await f.store.load(owner);assert.equal(unchanged.expenses[0].categoryId,id);
 await assert.rejects(f.command('RecordExpense',{...input(),categoryId:id}),{code:'NotFound'});
});
test('history 50/50/21, all-page totals, signed owner/filter/generation/expiry constraints and query purity',async()=>{
 const f=await fixture();for(let n=0;n<121;n++)await f.command('RecordExpense',input(n.toString().padStart(3,'0')));
 const before=f.store.writes;
 const one=await f.query('QueryHistory',{filter});const two=await f.query('QueryHistory',{filter,cursor:one.value.nextCursor});const three=await f.query('QueryHistory',{filter,cursor:two.value.nextCursor});
 assert.deepEqual([one.value.items.length,two.value.items.length,three.value.items.length],[50,50,21]);assert.equal(new Set([...one.value.items,...two.value.items,...three.value.items].map(x=>x.id)).size,121);
 const totals=await f.query('GetHistoryTotals',{filter,snapshotId:one.value.snapshotId});assert.equal(totals.value.total,12100);assert.equal(totals.value.count,121);assert.equal(f.store.writes,before);
 await assert.rejects(f.query('QueryHistory',{filter:{...filter,keyword:'other'},cursor:one.value.nextCursor}),{code:'CursorInvalidated'});
 await assert.rejects(f.query('QueryHistory',{filter,cursor:one.value.nextCursor+'x'}),{code:'CursorInvalidated'});
 await assert.rejects(f.service.query('other-owner',{operation:'QueryHistory',input:{filter,cursor:one.value.nextCursor}}),{code:'CursorInvalidated'});
 f.advance(900000);await assert.rejects(f.query('QueryHistory',{filter,cursor:one.value.nextCursor}),{code:'CursorInvalidated'});
 const fresh=await f.query('QueryHistory',{filter});await f.command('RecordExpense',input());await assert.rejects(f.query('GetHistoryTotals',{filter,snapshotId:fresh.value.snapshotId}),{code:'CursorInvalidated'});
});
test('budget calendar math, future expenses, warning delay, allocations, thresholds OFF receipts',async()=>{
 const f=await fixture();await f.command('ConfigureBudgetPlan',{expectedVersion:0,monthlyAmount:1000,startDay:25,notificationEnabled:false,categoryBudgetEnabled:true,allocations:[{categoryId:'cat_food',allocatedAmount:2000}]});
 await f.command('RecordExpense',{...input(undefined,1000),spentAt:'2026-11-20T03:00:00.000Z'});
 const r=await f.query('CalculateBudgetSummary',{asOfDate:'2026-11-01',timeZone:'America/New_York'});validate(r,'QueryResponse');assert.equal(r.value.periodStart,'2026-10-25');assert.equal(r.value.totalSpent,1000);assert.equal(r.value.daysTotal,31);assert.equal(r.value.daysRemaining,24);
 const a=await f.command('EvaluateBudgetThresholds',{asOfDate:'2026-11-01',timeZone:'Asia/Tokyo'});assert.deepEqual(a.value.map(x=>x.threshold),[80,100]);assert.ok(a.value.every(x=>!x.shouldNotify));
 const b=await f.command('EvaluateBudgetThresholds',{asOfDate:'2026-11-01',timeZone:'Asia/Tokyo'});assert.deepEqual(b.value,[]);
 const p={monthlyAmount:100,startDay:1};const s=D.budgetSummary(p,[input(undefined,200)],'2026-11-03','Asia/Tokyo');assert.equal(s.isProjectedToOverspend,false);
 assert.equal(D.budgetSummary(p,[input(undefined,200)],'2026-11-04','Asia/Tokyo').isProjectedToOverspend,true);
 assert.equal(D.localDate('2026-11-01T15:00:00.000Z','Asia/Tokyo'),'2026-11-02');
});
test('payment canonical source, normalization, exact ID and inclusive 180-second fallback, concurrent race',async()=>{
 const f=await fixture();const send=(p,id=randomUUID())=>f.service.command(owner,{operation:'IngestPayment',input:p,requestId:id},true);
 const p={amount:'¥1,280',merchant:'セブン',external_tx_id:'tx1'};const requestId=randomUUID();const created=await send(p,requestId);validate(created,'PaymentResponse');assert.equal(created.status,'created');
 f.advance(100000);assert.deepEqual(await send(p,requestId),created);assert.equal((await send(p)).status,'duplicate');
 assert.equal((await f.query('GetExpense',{id:created.expense_id})).value.categoryId,'cat_food');
 const base={amount:200,merchant:'Other',spent_at:date};await send(base);
 assert.equal((await send({...base,spent_at:'2026-11-01T03:03:00Z'})).status,'duplicate');
 assert.equal((await send({...base,spent_at:'2026-11-01T03:03:01Z'})).status,'created');
 const parallel=await Promise.all([send({amount:900,merchant:'parallel'}),send({amount:900,merchant:'parallel'})]);assert.deepEqual(parallel.map(x=>x.status).sort(),['created','duplicate']);
 for(const amount of ['1+2','-5','NaN','1.5',''])await assert.rejects(send({amount}),{code:'ValidationFailed'});
});
test('HTTP provider verifies owner, envelope, extra fields, no legacy endpoints and read types',async()=>{
 const f=await fixture();
 const call=async(path,body,headers={'x-user-id':owner},method='POST')=>{const r=await f.handler({rawPath:path,requestContext:{http:{method}},headers,body:JSON.stringify(body)});return {...r,json:JSON.parse(r.body)};};
 assert.equal((await call('/health',{}, {},'GET')).statusCode,200);
 assert.equal((await call('/sync/push',{})).statusCode,404);
 assert.equal((await call('/queries',{schemaVersion:2,operation:'GetCatalog',input:{}})).statusCode,400);
 assert.equal((await call('/queries',{schemaVersion:3,operation:'GetCatalog',input:{},extra:1})).statusCode,400);
 assert.equal((await call('/queries',{schemaVersion:3,operation:'GetCatalog',input:{}},{'x-user-id':'other'})).statusCode,403);
 for(const op of ['GetCatalog','GetBudgetPlan']){const r=await call('/queries',{schemaVersion:3,operation:op,input:{}});assert.equal(r.statusCode,op==='GetCatalog'?200:404);if(r.statusCode===200)validate(r.json,'QueryResponse');else validate(r.json,'Error');}
 const wrong=await call('/payment',{requestId:randomUUID(),user_id:'other',amount:1});assert.equal(wrong.statusCode,403);
 assert.ok(!matches({schemaVersion:3,operation:'GetCatalog',value:{},readGeneration:0,warnings:[]},schema.$defs.QueryResponse));
});
test('query retries generation drift twice and returns Busy instead of mixed results',async()=>{
 const f=await fixture();const original=f.store.load.bind(f.store);let changes=0;
 f.store.load=async owner=>{const data=await original(owner);if(changes++<2)f.store.tables.metadata.set(owner+'/generation',{value:(await f.store.generation(owner))+1});return data;};
 const r=await f.query('GetCatalog');assert.equal(changes,3);assert.equal(r.readGeneration,3);
 f.store.load=async owner=>{const data=await original(owner);f.store.tables.metadata.set(owner+'/generation',{value:(await f.store.generation(owner))+1});return data;};
 await assert.rejects(f.query('GetCatalog'),{code:'Busy'});
});
test('Unicode literal AND/OR/source filters preserve unfiltered month total and local day totals',async()=>{
 const f=await fixture();await f.command('RecordExpense',{...input('a',100),memo:'  ＡＢＣ [x]  '});await f.command('RecordExpense',{...input('b',200),categoryId:'cat_daily',memo:'abc [x]'});await f.command('RecordExpense',{...input('c',300),memo:'different'});
 const filter={month:'2026-11',keyword:'AbC [x]',categoryIds:['cat_food','cat_daily'],source:'manual',timeZone:'Asia/Tokyo'};
 const page=await f.query('QueryHistory',{filter});assert.deepEqual(page.value.items.map(e=>e.id),['b','a']);const totals=await f.query('GetHistoryTotals',{filter,snapshotId:page.value.snapshotId});assert.equal(totals.value.total,300);assert.equal(totals.value.monthTotal,600);assert.deepEqual(totals.value.dayTotals,[{date:'2026-11-01',total:300}]);
});
test('all generated consumer/provider fixtures and stored events conform to canonical schemas',async()=>{
 const fs=require('node:fs');const fixtures=JSON.parse(fs.readFileSync(require('node:path').join(__dirname,'../../test/fixtures/api-v3.json'),'utf8'));
 for(const f of fixtures){validate(f.request,f.path==='/payment'?'PaymentInput':f.path==='/commands'?'CommandRequest':'QueryRequest');validate(f.response,f.path==='/payment'?'PaymentResponse':f.path==='/commands'?'CommandResponse':'QueryResponse');}
 const vectors=require('../../docs/spec/contracts/examples.json').vectors;
 for(const v of vectors){const target=v.schema.startsWith('events')?require('../contracts/events.schema.json'):schema.$defs[v.schema.split('/').at(-1)];assert.equal(matches(v.value,target),v.valid,v.name);}
 const f=await fixture();await f.command('RecordExpense',input());const eventSchema=require('../contracts/events.schema.json');
 for(const e of f.store.tables.events.values())assert.ok(matches(e,eventSchema));
});
test('notification receipt does not invalidate a ledger read snapshot',async()=>{
 const f=await fixture();await f.command('ConfigureBudgetPlan',{expectedVersion:0,monthlyAmount:100,startDay:1,notificationEnabled:false,categoryBudgetEnabled:false,allocations:[]});await f.command('RecordExpense',input());
 const page=await f.query('QueryHistory',{filter});const generation=await f.store.generation(owner);
 await f.command('EvaluateBudgetThresholds',{asOfDate:'2026-11-01',timeZone:'Asia/Tokyo'});assert.equal(await f.store.generation(owner),generation);
 assert.equal((await f.query('GetHistoryTotals',{filter,snapshotId:page.value.snapshotId})).value.total,100);
});
