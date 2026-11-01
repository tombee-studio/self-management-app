const {Service}=require('../server/application/service');const {Tokens}=require('../server/infrastructure/tokens');const {MemoryStore}=require('../server/test/support');const {randomUUID}=require('crypto');const fs=require('fs');
(async()=>{
 const s=new Service({store:new MemoryStore(),tokens:new Tokens('fixture-secret-with-at-least-32-characters'),uuid:randomUUID,clock:()=> '2026-11-01T03:00:00.000Z'});
 const records=[];
 async function command(operation,input){const request={schemaVersion:3,operation,input,requestId:randomUUID()};const response=await s.command('fixture',request);records.push({path:'/commands',request,response});return response.value;}
 async function query(operation,input={}){const request={schemaVersion:3,operation,input};const response=await s.query('fixture',request);records.push({path:'/queries',request,response});return response.value;}
 await command('EnsureDefaultCatalog',{});await query('GetCatalog');
 const e=await command('RecordExpense',{id:randomUUID(),amount:1280,categoryId:'cat_food',spentAt:'2026-11-01T03:00:00.000Z',paymentMethod:'cash',memo:'ランチ'});
 await query('GetExpense',{id:e.id});
 await command('ModifyExpense',{id:e.id,expectedVersion:1,changes:{memo:'昼食'}});
 const deleted=await command('DeleteExpense',{id:e.id,expectedVersion:2,kind:'swipe'});
 await command('RestoreExpense',{grant:deleted.undoGrant});
 await command('ConfigureBudgetPlan',{expectedVersion:0,monthlyAmount:100000,startDay:1,allocations:[],notificationEnabled:true,categoryBudgetEnabled:false});await query('GetBudgetPlan');
 for(const operation of ['WatchDailySummary','RefreshDailyProjection'])await query(operation,{date:'2026-11-01',timeZone:'Asia/Tokyo'});
 const filter={month:'2026-11',keyword:'',categoryIds:[],source:null,timeZone:'Asia/Tokyo'};
 const page=await query('QueryHistory',{filter});await query('GetHistoryTotals',{filter,snapshotId:page.snapshotId});
 await query('CalculateBudgetSummary',{asOfDate:'2026-11-01',timeZone:'Asia/Tokyo'});
 await command('EvaluateBudgetThresholds',{asOfDate:'2026-11-01',timeZone:'Asia/Tokyo'});
 const catalog=await command('UpsertCategory',{categoryId:randomUUID(),expectedCatalogVersion:1,name:'テスト',iconKey:'folder',colorHex:'#123456'});
 await command('ReorderCatalog',{expectedCatalogVersion:2,orderedIds:catalog.categories.map(x=>x.id).reverse()});
 await command('RetireCategory',{categoryId:catalog.categories.at(-1).id,expectedCatalogVersion:3});
 const request={requestId:randomUUID(),amount:'¥1,280',merchant:'セブン'};records.push({path:'/payment',request,response:await s.command('fixture',{operation:'IngestPayment',input:request,requestId:request.requestId},true)});
 fs.writeFileSync('test/fixtures/api-v3.json',JSON.stringify(records,null,2)+'\n');
})().catch(e=>{console.error(e);process.exitCode=1;});
