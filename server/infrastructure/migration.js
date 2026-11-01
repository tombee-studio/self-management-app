'use strict';
// Pure server-side conversion of a document-client JSON backup. No device DB access.
const D=require('../domain/model');const {validate}=require('../api/schema');
const {createHash}=require('node:crypto');
function normalizePaymentMethod(method) {
 if(!method)return 'cash';
 const m=String(method).toLowerCase().replace(/[\s_-]/g,'');
 if(m==='cash'||m==='manual')return 'cash';
 if(m==='applepay')return 'applePay';
 if(m==='creditcard')return 'creditCard';
 if(m==='emoney')return 'eMoney';
 if(m==='other')return 'other';
 return 'cash';
}
function migrate(backup,ownerId) {
 if(!ownerId||backup.ownerId!==ownerId)D.fail('OwnerMismatch');
 for(const rows of [backup.categories||[],backup.expenses||[],backup.budgets||[],backup.categoryBudgets||[]])for(const row of rows)if(row.user_id&&row.user_id!==ownerId)D.fail('OwnerMismatch');
 const catalog={version:1,retired:{},categories:[]},names=new Set();
 const source=[...(backup.categories||[])].sort((a,b)=>a.category_id.localeCompare(b.category_id));
 for(const old of source){
  if(old.is_deleted){catalog.retired[old.category_id]=D.uncategorized;continue;}
  let name=(old.name||'').trim();if(!name)D.fail('ValidationFailed','name');
  name=D.graphemes(name).slice(0,20).join('');const base=name;let suffix=1;
  while(names.has(D.key(name))){const tail=` (${++suffix})`;name=D.graphemes(base).slice(0,20-D.graphemes(tail).length).join('')+tail;}
  names.add(D.key(name));
  const iconKey=old.icon_key||old.icon_name||'folder';
  catalog.categories.push({id:old.category_id,name,nameKey:D.key(name),iconKey,colorHex:old.color_hex,sortOrder:old.sort_order||0,isSystem:old.category_id===D.uncategorized});
 }
 if(!catalog.categories.some(c=>c.id===D.uncategorized))catalog.categories.push(D.defaults().categories.at(-1));
 catalog.categories=catalog.categories.sort((a,b)=>a.sortOrder-b.sortOrder||a.id.localeCompare(b.id)).map((x,sortOrder)=>({...x,sortOrder}));
 if(new Set(catalog.categories.map(c=>c.id)).size!==catalog.categories.length)D.fail('InvariantViolation','categoryId');
 validate(D.catalogView(catalog),'CatalogView');
 const expenses=(backup.expenses||[]).map(old=>{
  const categoryId=catalog.categories.some(c=>c.id===old.category_id)?old.category_id:D.uncategorized;
  const isDeleted=old.is_deleted===true;
  if(!isDeleted&&(!Number.isInteger(old.amount)||old.amount<1||old.amount>99999999))D.fail('ValidationFailed','amount');
  const amount=isDeleted?(Number.isInteger(old.amount)&&old.amount>=1?old.amount:1):old.amount;
  const rawMemo=(old.memo||old.merchant_name||'').trim();
  const memo=rawMemo?D.graphemes(rawMemo).slice(0,100).join(''):null;
  const paymentMethod=normalizePaymentMethod(old.payment_method);
  const source=(old.source==='apple_pay'||old.payment_method==='Apple Pay'||old.payment_method==='applePay')?'apple_pay':(old.source||'manual');
  const e={id:old.expense_id,amount,categoryId,spentAt:new Date(old.spent_at).toISOString(),memo,paymentMethod,source,externalTxId:old.external_tx_id||null,version:1,isDeleted,merchantKey:D.key(memo||''),memoSearch:D.key(memo||'')};
  if(!isDeleted)validate(D.expenseView(e,catalog),'ExpenseView');
  return e;
 });
 if(new Set(expenses.map(e=>e.id)).size!==expenses.length)D.fail('InvariantViolation','expenseId');
 let budget=null;
 if((backup.budgets||[]).length>1)D.fail('InvariantViolation','budget');
 if(backup.budgets?.length){const p=backup.budgets[0];budget={monthlyAmount:p.monthly_amount,startDay:p.start_day,notificationEnabled:p.is_alert_notification_enabled??true,categoryBudgetEnabled:p.is_category_budget_enabled??false,version:1,
  allocations:(backup.categoryBudgets||[]).filter(a=>catalog.categories.some(c=>c.id===a.category_id)).map(a=>({categoryId:a.category_id,allocatedAmount:a.allocated_amount}))};validate(budget,'BudgetPlanView');}
 const rows=[{table:'categories',id:'catalog',data:catalog},...(budget?[{table:'budgets',id:'current',data:budget}]:[]),...expenses.map(e=>({table:'expenses',id:e.id,data:e})),{table:'metadata',id:'generation',data:{value:1}}];
 const external=new Set();
 for(const e of expenses){if(e.externalTxId){const id=`external#${e.source}#${e.externalTxId}`;if(external.has(id))D.fail('InvariantViolation','externalTxId');external.add(id);rows.push({table:'metadata',id,data:{expenseId:e.id}});}}
 const count=expenses.filter(e=>!e.isDeleted).length,total=expenses.filter(e=>!e.isDeleted).reduce((n,e)=>n+e.amount,0);
 return {ownerId,backupDigest:createHash('sha256').update(JSON.stringify(backup)).digest('hex'),manifest:{count,total,ids:expenses.map(e=>e.id).sort(),categoryIds:catalog.categories.map(c=>c.id).sort()},rows:rows.map(r=>({...r,ownerId}))};
}
module.exports={migrate};
