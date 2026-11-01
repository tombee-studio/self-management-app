'use strict';
class DomainError extends Error {
  constructor(code, field = null) { super(code); this.code = code; this.field = field; }
}
const fail = (code, field) => { throw new DomainError(code, field); };
const key = s => s.normalize('NFKC').toLowerCase().trim();
const graphemes = s => [...new Intl.Segmenter('ja', {granularity:'grapheme'}).segment(s)].map(x=>x.segment);
const uncategorized = 'cat_uncategorized';
const defaults = () => ({version:1, retired:{}, categories:[
 ['cat_food','食費','restaurant','#F97316'],['cat_daily','日用品','shopping_bag','#14B8A6'],
 ['cat_transport','交通費','train','#3B82F6'],['cat_cafe','カフェ・外食','local_cafe','#A16207'],
 ['cat_clothing','衣服・美容','checkroom','#EC4899'],['cat_medical','医療・健康','medical_services','#EF4444'],
 ['cat_entertainment','趣味・娯楽','sports_esports','#8B5CF6'],['cat_home','住まい・通信','home','#6366F1'],
 [uncategorized,'未分類','folder','#94A3B8']
].map(([id,name,iconKey,colorHex],sortOrder)=>({id,name,iconKey,colorHex,sortOrder,nameKey:key(name),isSystem:id===uncategorized}))});
const icons = ['restaurant','shopping_bag','train','local_cafe','checkroom','medical_services','sports_esports','home','folder'];
function category(catalog,id) { if (!catalog?.categories.some(c=>c.id===id)) fail('NotFound','categoryId'); return id; }
function resolved(catalog,id) { return catalog && Object.hasOwn(catalog.retired,id) ? catalog.retired[id] : id; }
function expenseView(e,catalog) { const {id,amount,spentAt,paymentMethod,memo,source,externalTxId,version}=e; return {id,amount,categoryId:resolved(catalog,e.categoryId),spentAt,paymentMethod,memo,source,externalTxId,version}; }
function catalogView(c) { return {version:c.version,categories:c.categories.map(({id,name,iconKey,colorHex,sortOrder,isSystem})=>({id,name,iconKey,colorHex,sortOrder,isSystem}))}; }
function normalizeExpense(input,catalog) {
 if(typeof input.id!=='undefined' && (typeof input.id!=='string'||!input.id))fail('ValidationFailed','id');
 if(input.memo!==null && input.memo!==undefined && typeof input.memo!=='string')fail('ValidationFailed','memo');
 category(catalog,input.categoryId);
 const memo = input.memo?.trim().replace(/[\r\n]+/g,' ') || null;
 if(memo && graphemes(memo).length>100)fail('ValidationFailed','memo');
 if(!Number.isInteger(input.amount)||input.amount<1||input.amount>99999999)fail('ValidationFailed','amount');
 if(!Number.isFinite(Date.parse(input.spentAt))||Date.parse(input.spentAt)<0)fail('ValidationFailed','spentAt');
 if(!['cash','applePay','creditCard','eMoney','other'].includes(input.paymentMethod))fail('ValidationFailed','paymentMethod');
 return {...input,memo,memoSearch:key(memo||'')};
}
function localDate(stamp,timeZone) {
 try { const p = new Intl.DateTimeFormat('en-CA',{timeZone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(stamp));
 return ['year','month','day'].map(k=>p.find(x=>x.type===k).value).join('-');
 } catch { fail('ValidationFailed','timeZone'); }
}
const dayValue = s => Date.parse(s+'T00:00:00Z')/86400000;
function dateCheck(s) { if(!/^\d{4}-\d{2}-\d{2}$/.test(s)||!Number.isFinite(dayValue(s))||new Date(dayValue(s)*86400000).toISOString().slice(0,10)!==s||s<'1970-01-01')fail('ValidationFailed','date'); }
function budgetSummary(plan,expenses,asOfDate,timeZone) {
 dateCheck(asOfDate); localDate(0,timeZone);
 const [y,m,d]=asOfDate.split('-').map(Number);
 const start = new Date(Date.UTC(y,m-1-(d<plan.startDay?1:0),plan.startDay));
 const end = new Date(Date.UTC(start.getUTCFullYear(),start.getUTCMonth()+1,plan.startDay));
 const periodStart=start.toISOString().slice(0,10), periodEndExclusive=end.toISOString().slice(0,10);
 const totalSpent=expenses.filter(e=>{const d=localDate(e.spentAt,timeZone);return d>=periodStart&&d<periodEndExclusive;}).reduce((n,e)=>n+e.amount,0);
 const daysTotal=dayValue(periodEndExclusive)-dayValue(periodStart), daysPassed=dayValue(asOfDate)-dayValue(periodStart)+1,daysRemaining=dayValue(periodEndExclusive)-dayValue(asOfDate);
 const remainingBudget=plan.monthlyAmount-totalSpent,projectedTotalExpense=Math.floor(totalSpent/daysPassed*daysTotal);
 return {periodStart,periodEndExclusive,totalSpent,remainingBudget,dailyRecommended:Math.max(0,Math.floor(remainingBudget/daysRemaining)),projectedTotalExpense,daysTotal,daysPassed,daysRemaining,isOverBudget:remainingBudget<0,isProjectedToOverspend:daysPassed>3&&projectedTotalExpense>plan.monthlyAmount};
}
function normalizePayment(p,now,catalog) {
 const amount = typeof p.amount==='number'?p.amount:Number(p.amount.replace(/[¥￥,\s]/g,''));
 if(typeof p.amount==='string'&&!/^\d+$/.test(p.amount.replace(/[¥￥,\s]/g,'')))fail('ValidationFailed','amount');
 if(p.spent_at!==undefined&&!Number.isFinite(Date.parse(p.spent_at)))fail('ValidationFailed','spent_at');
 const spentAt=p.spent_at===undefined?now:new Date(p.spent_at).toISOString();
 const memo=graphemes((p.merchant||'').trim().replace(/[\r\n]+/g,' ')).slice(0,100).join('')||null;
 const merchantKey=key(p.merchant||'');
 let categoryId=uncategorized;
 for(const [id,pattern] of [['cat_transport',/jr|東京メトロ|suica|タクシー|eneos/],['cat_daily',/マツモトキヨシ|ウエルシア|ダイソー/],['cat_food',/セブン|ローソン|ファミリーマート|マクドナルド|スタバ/]]) {
 if(pattern.test(merchantKey)) {categoryId=catalog.categories.some(c=>c.id===id)?id:uncategorized;break;}
 }
 return {...normalizeExpense({amount,spentAt,memo,categoryId,paymentMethod:'applePay'},catalog),source:'apple_pay',externalTxId:p.external_tx_id||null,merchantKey};
}
module.exports={DomainError,fail,key,graphemes,uncategorized,defaults,icons,category,resolved,expenseView,catalogView,normalizeExpense,localDate,dateCheck,budgetSummary,normalizePayment};
