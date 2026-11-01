'use strict';
const D=require('../domain/model');
const {Expense,CategoryCatalog,BudgetPlan}=require('../domain/aggregates');
const clone=x=>structuredClone(x);
const equal=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
class Service {
 constructor({store,tokens,clock=()=>new Date().toISOString(),uuid}) {Object.assign(this,{store,tokens,clock,uuid});}
 async snapshot(owner) {
  for(let attempt=0;attempt<3;attempt++) {
   const generation=await this.store.generation(owner);
   const data=await this.store.load(owner);
   if(generation===await this.store.generation(owner))return {...data,generation};
  }
  D.fail('Busy');
 }
 async command(owner,request,payment=false) {
  const {operation,input,requestId}=request;
  const fingerprint=this.tokens.hash({operation,input});
  const receipt=await this.store.get(owner,'metadata','receipt#'+requestId);
  if(receipt) {if(receipt.fingerprint!==fingerprint)D.fail('VersionConflict');return receipt.response;}
  for(let attempt=0;attempt<3;attempt++) {
   const s=await this.snapshot(owner), now=this.clock();
   const baseline={...s};
   const changes=[],events=[],warnings=[];
   let value, changed=false;
   const put=(table,id,data)=>{changes.push({table,id,data});if(table!=='metadata')changed=true;};
   const event=(type,id,version,payload)=>events.push({eventId:`${id}/${version}/${type}`,eventType:type,schemaVersion:2,aggregateId:id,aggregateVersion:version,occurredAt:now,payload});
   const live=s.expenses.filter(e=>!e.isDeleted);
   const getExpense=id=>{const e=s.expenses.find(e=>e.id===id);if(!e)D.fail('NotFound');return clone(e);};
   const checkVersion=(actual,expected)=>{if(actual!==expected)D.fail('VersionConflict');};
   const ensureCatalog=()=>{if(!s.catalog)D.fail('NotFound');};
   const saveExpense=(e,type)=>{
    e={...e,createdAt:e.createdAt||now,updatedAt:now};
    put('expenses',e.id,e); value=D.expenseView(e,s.catalog);
    const {id:expenseId,amount,categoryId,spentAt,memo}=value;
    event(type,e.id,e.version,type==='ExpenseDeleted'?{expenseId}:{expenseId,amount,categoryId,spentAt,memo});
   };
   const saveCatalog=(catalog,type='CatalogChanged',payload=null)=>{
    put('categories','catalog',catalog);s.catalog=catalog;value=D.catalogView(catalog);
    event(type,'catalog',catalog.version,payload||{catalogId:'catalog',categoryIds:catalog.categories.map(c=>c.id)});
   };
   const saveBudget=plan=>{
    put('budgets','current',plan);s.budget=plan;value=plan;
    event('BudgetPlanChanged','current',plan.version,{budgetPlanId:'current',monthlyAmount:plan.monthlyAmount,startDay:plan.startDay});
   };
   switch(operation) {
    case 'EnsureDefaultCatalog':
     if(s.catalog){value=D.catalogView(s.catalog);warnings.push('AlreadyApplied');}else saveCatalog(D.defaults());
     break;
    case 'RecordExpense': {
     ensureCatalog();const normalized=D.normalizeExpense(input,s.catalog),old=s.expenses.find(e=>e.id===input.id);
     if(old) {if(old.isDeleted||!equal(D.normalizeExpense(Object.fromEntries(Object.keys(input).map(k=>[k,old[k]])),s.catalog),normalized))D.fail('VersionConflict');value=D.expenseView(old,s.catalog);warnings.push('AlreadyApplied');break;}
     saveExpense(Expense.record(input,s.catalog).state,'ExpenseRecorded');break;
    }
    case 'ModifyExpense': {
     const e=getExpense(input.id);if(e.isDeleted)D.fail('NotFound');checkVersion(e.version,input.expectedVersion);
     const updated=new Expense(e).modify(input.changes,s.catalog).state;
     if(equal(e,updated)){value=D.expenseView(e,s.catalog);warnings.push('AlreadyApplied');}else saveExpense(updated,'ExpenseChanged');break;
    }
    case 'DeleteExpense': {
     const e=getExpense(input.id);
     if(e.isDeleted){value={id:e.id,version:e.version,undoGrant:null};warnings.push('AlreadyDeleted');break;}
     checkVersion(e.version,input.expectedVersion);
     saveExpense(new Expense(e).delete().state,'ExpenseDeleted');
     const grant=input.kind==='swipe'?this.uuid():null;
     if(grant)put('metadata','undo#'+grant,{expenseId:e.id,deletedVersion:e.version+1,original:e,deletedAt:now,used:false});
     value={id:e.id,version:e.version+1,undoGrant:grant};break;
    }
    case 'RestoreExpense': {
     const grant=await this.store.get(owner,'metadata','undo#'+input.grant);
     if(!grant)D.fail('UndoExpired');
     if(grant.used){value=grant.result;warnings.push('AlreadyApplied');break;}
     if(Date.parse(now)-Date.parse(grant.deletedAt)>=30000)D.fail('UndoExpired');
     const e=getExpense(grant.expenseId);checkVersion(e.version,grant.deletedVersion);if(!e.isDeleted)D.fail('VersionConflict');
     saveExpense({...grant.original,categoryId:D.resolved(s.catalog,grant.original.categoryId),version:e.version+1,isDeleted:false},'ExpenseRestored');
     put('metadata','undo#'+input.grant,{...grant,used:true,result:value});break;
    }
    case 'UpsertCategory': {
     ensureCatalog();const c=clone(s.catalog);checkVersion(c.version,input.expectedCatalogVersion);
     const updated=new CategoryCatalog(c).upsert(input).state;
     if(updated.version===c.version){value=D.catalogView(c);warnings.push('AlreadyApplied');break;}
     saveCatalog(updated);break;
    }
    case 'ReorderCatalog': {
     ensureCatalog();const c=clone(s.catalog);checkVersion(c.version,input.expectedCatalogVersion);
     const updated=new CategoryCatalog(c).reorder(input.orderedIds).state;
     if(updated.version===c.version){value=D.catalogView(c);warnings.push('AlreadyApplied');break;}
     saveCatalog(updated);break;
    }
    case 'RetireCategory': {
     ensureCatalog();const c=clone(s.catalog);
     if(input.categoryId===D.uncategorized)D.fail('InvariantViolation');
     if((Object.hasOwn(c.retired,input.categoryId) ? c.retired[input.categoryId] : null)) {value={categoryId:input.categoryId,version:c.version,movedExpenseCount:0};warnings.push('AlreadyRetired');break;}
     checkVersion(c.version,input.expectedCatalogVersion);D.category(c,input.categoryId);
     const movedExpenseCount=live.filter(e=>D.resolved(c,e.categoryId)===input.categoryId).length;
     const retired=new CategoryCatalog(c).retire(input.categoryId).state;
     saveCatalog(retired,'CategoryRetired',{categoryId:input.categoryId,targetCategoryId:D.uncategorized,movedExpenseCount});
     if(s.budget)saveBudget(BudgetPlan.removeAllocation(s.budget,input.categoryId));
     value={categoryId:input.categoryId,version:retired.version,movedExpenseCount};break;
    }
    case 'ConfigureBudgetPlan': {
     ensureCatalog();checkVersion(s.budget?.version||0,input.expectedVersion);
     const plan=BudgetPlan.configure(input,s.catalog,s.budget);
     if(plan.allocations.reduce((n,a)=>n+a.allocatedAmount,0)>plan.monthlyAmount)warnings.push('AllocationExceedsBudget');
     if(plan===s.budget){value=s.budget;warnings.push('AlreadyApplied');break;}
     saveBudget(plan);break;
    }
    case 'EvaluateBudgetThresholds': {
     if(!s.budget)D.fail('NotFound');
     const summary=D.budgetSummary(s.budget,live,input.asOfDate,input.timeZone);value=[];
     for(const threshold of [80,100]) {
      if(summary.totalSpent*100<s.budget.monthlyAmount*threshold)continue;
      const notificationId=`notification#${summary.periodStart}#${threshold}`;
      if(await this.store.get(owner,'metadata',notificationId))continue;
      put('metadata',notificationId,{periodStart:summary.periodStart,threshold});
      value.push({notificationId,threshold,periodStart:summary.periodStart,shouldNotify:s.budget.notificationEnabled});
     }break;
    }
    case 'IngestPayment': {
     ensureCatalog();const normalized=D.normalizePayment(input,now,s.catalog);
     const external=normalized.externalTxId?await this.store.get(owner,'metadata',`external#apple_pay#${normalized.externalTxId}`):null;
     const duplicate=external?s.expenses.find(e=>e.id===external.expenseId):s.expenses.find(e=>e.source==='apple_pay'&&(normalized.externalTxId?e.externalTxId===normalized.externalTxId:e.amount===normalized.amount&&e.merchantKey===normalized.merchantKey&&Math.abs(Date.parse(e.spentAt)-Date.parse(normalized.spentAt))<=180000));
     if(duplicate){value={status:'duplicate',expense_id:duplicate.id};break;}
     const id=this.uuid();saveExpense({...normalized,id,version:1,isDeleted:false},'ExpenseRecorded');
     if(normalized.externalTxId)put('metadata',`external#apple_pay#${normalized.externalTxId}`,{expenseId:id});
     value={status:'created',expense_id:id};break;
    }
    default:D.fail('ValidationFailed');
   }
   const response=payment?{schemaVersion:3,requestId,...value,readGeneration:s.generation+(changed?1:0)}:{schemaVersion:3,operation,requestId,value,warnings,readGeneration:s.generation+(changed?1:0)};
   changes.push({table:'metadata',id:'receipt#'+requestId,data:{fingerprint,operation,normalizedInput:input,receivedAt:now,response}});
   try {await this.store.commit(owner,baseline,changes,events,changed);return response;}
   catch(e) {
    if(e.code!=='VersionConflict')throw e;
    const stored=await this.store.get(owner,'metadata','receipt#'+requestId);
    if(stored){if(stored.fingerprint!==fingerprint)D.fail('VersionConflict');return stored.response;}
    if(attempt===2)throw e;
   }
  }
 }
 async query(owner,{operation,input}) {
  const s=await this.snapshot(owner),live=s.expenses.filter(e=>!e.isDeleted).map(e=>D.expenseView(e,s.catalog));
  let value;
  const summary=(date,zone)=>{if(!s.budget)D.fail('NotFound');return D.budgetSummary(s.budget,live,date,zone);};
  switch(operation) {
   case 'GetExpense':value=live.find(e=>e.id===input.id);if(!value)D.fail('NotFound');break;
   case 'GetCatalog':if(!s.catalog)D.fail('NotFound');value=D.catalogView(s.catalog);break;
   case 'GetBudgetPlan':if(!s.budget)D.fail('NotFound');value=s.budget;break;
   case 'CalculateBudgetSummary':value=summary(input.asOfDate,input.timeZone);break;
   case 'WatchDailySummary':case 'RefreshDailyProjection': {
    D.dateCheck(input.date);D.localDate(0,input.timeZone);
    if(input.afterReadGeneration>s.generation)D.fail('Busy');
    const items=live.filter(e=>D.localDate(e.spentAt,input.timeZone)===input.date).sort(sortExpense);
    const amounts=new Map();items.forEach(e=>amounts.set(e.categoryId,(amounts.get(e.categoryId)||0)+e.amount));
    value={date:input.date,total:items.reduce((n,e)=>n+e.amount,0),categoryBreakdown:[...amounts].map(([categoryId,amount])=>({categoryId,amount})),items,snapshotId:this.tokens.sign({owner,generation:s.generation,filter:input.date,timeZone:input.timeZone}),budgetHint:s.budget?summary(input.date,input.timeZone):null};break;
   }
   case 'QueryHistory':case 'GetHistoryTotals': {
    const f=input.filter;D.localDate(0,f.timeZone);if(f.date)D.dateCheck(f.date);
    if(f.date&&(!f.month||!f.date.startsWith(f.month+'-')))D.fail('ValidationFailed','date');
    const fingerprint=this.tokens.hash(f);
    const token=input.cursor||input.snapshotId;
    const position=token?this.tokens.verify(token):null;
    if(position&&(position.owner!==owner||position.generation!==s.generation||position.filter!==fingerprint||position.timeZone!==f.timeZone))D.fail('CursorInvalidated');
    const snapshotId=input.snapshotId||position?.snapshotId||this.tokens.sign({owner,generation:s.generation,filter:fingerprint,timeZone:f.timeZone});
    const monthItems=live.filter(e=>!f.month||D.localDate(e.spentAt,f.timeZone).startsWith(f.month+'-'));
    const items=monthItems.filter(e=>(!f.date||D.localDate(e.spentAt,f.timeZone)===f.date)&&(!f.keyword||D.key(e.memo||'').includes(D.key(f.keyword)))&&(!f.categoryIds.length||f.categoryIds.includes(e.categoryId))&&(!f.source||f.source===e.source)).sort(sortExpense);
    if(operation==='GetHistoryTotals') {
     const days=new Map();items.forEach(e=>{const d=D.localDate(e.spentAt,f.timeZone);days.set(d,(days.get(d)||0)+e.amount);});
     value={count:items.length,total:items.reduce((n,e)=>n+e.amount,0),monthTotal:f.month?monthItems.reduce((n,e)=>n+e.amount,0):null,dayTotals:[...days].map(([date,total])=>({date,total})),snapshotId};
    }else {
     const remaining=position?.last?items.filter(e=>sortExpense(e,position.last)>0):items;
     const page=remaining.slice(0,50);
     value={items:page,nextCursor:remaining.length>50?this.tokens.sign({owner,generation:s.generation,filter:fingerprint,timeZone:f.timeZone,last:{spentAt:page.at(-1).spentAt,id:page.at(-1).id},snapshotId}):null,snapshotId};
    }break;
   }
   default:D.fail('ValidationFailed');
  }
  return {schemaVersion:3,operation,value,warnings:[],readGeneration:s.generation};
 }
}
function sortExpense(a,b) {return b.spentAt.localeCompare(a.spentAt)||b.id.localeCompare(a.id);}
module.exports={Service};
