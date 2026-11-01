const {test}=require('node:test');const assert=require('node:assert/strict');const {migrate}=require('../infrastructure/migration');
test('cloud-only migration preserves IDs/count/money, repairs name collisions and leaves backup unchanged',()=>{
 const backup={ownerId:'o',categories:[{category_id:'a',name:'ＡＢＣ',icon_key:'folder',color_hex:'#123456'},{category_id:'b',name:'abc',icon_key:'folder',color_hex:'#123456'}],expenses:[{expense_id:'e',amount:1280,category_id:'a',spent_at:'2026-11-01T00:00:00Z'}],budgets:[]};
 const before=structuredClone(backup),r=migrate(backup,'o');assert.deepEqual(backup,before);assert.equal(r.manifest.count,1);assert.equal(r.manifest.total,1280);assert.deepEqual(r.manifest.ids,['e']);assert.equal(r.rows.find(x=>x.table==='expenses').data.categoryId,'a');assert.equal(r.rows.find(x=>x.table==='categories').data.categories.find(c=>c.id==='b').name,'abc (2)');
 const bad=structuredClone(backup);bad.expenses[0].amount=-1;assert.throws(()=>migrate(bad,'o'));assert.deepEqual(backup,before);assert.throws(()=>migrate(backup,'other'),{code:'OwnerMismatch'});const wrong=structuredClone(backup);wrong.expenses[0].user_id='other';assert.throws(()=>migrate(wrong,'o'),{code:'OwnerMismatch'});
});

test('migration normalizes legacy schemas (icon_name, merchant_name, manual/Apple Pay, deleted zero amount)',()=>{
 const backup={
  ownerId:'owner_1',
  categories:[
   {category_id:'cat_cafe',name:'カフェ',icon_name:'local_cafe',color_hex:'#F59E0B'},
   {category_id:'cat_cloth',name:'衣服',icon_key:'checkroom',color_hex:'#EC4899'}
  ],
  expenses:[
   {expense_id:'e1',amount:500,category_id:'cat_cafe',spent_at:'2026-10-20T08:00:00Z',merchant_name:'スタバ',payment_method:'manual'},
   {expense_id:'e2',amount:1200,category_id:'cat_cloth',spent_at:'2026-10-21T10:00:00Z',memo:'UNIQRO',payment_method:'Apple Pay'},
   {expense_id:'e3',amount:0,category_id:'unknown',spent_at:'2026-10-22T12:00:00Z',payment_method:'manual',is_deleted:true}
  ],
  budgets:[{monthly_amount:100000,start_day:1,is_alert_notification_enabled:true,is_category_budget_enabled:false}]
 };
 const r=migrate(backup,'owner_1');
 assert.equal(r.manifest.count,2);
 assert.equal(r.manifest.total,1700);
 assert.deepEqual(r.manifest.ids,['e1','e2','e3']);
 const cat=r.rows.find(x=>x.table==='categories').data;
 assert.equal(cat.categories.find(c=>c.id==='cat_cafe').iconKey,'local_cafe');
 const exp1=r.rows.find(x=>x.table==='expenses'&&x.id==='e1').data;
 assert.equal(exp1.memo,'スタバ');
 assert.equal(exp1.paymentMethod,'cash');
 assert.equal(exp1.source,'manual');
 const exp2=r.rows.find(x=>x.table==='expenses'&&x.id==='e2').data;
 assert.equal(exp2.memo,'UNIQRO');
 assert.equal(exp2.paymentMethod,'applePay');
 assert.equal(exp2.source,'apple_pay');
 const exp3=r.rows.find(x=>x.table==='expenses'&&x.id==='e3').data;
 assert.equal(exp3.isDeleted,true);
 assert.equal(exp3.amount,1);
 assert.equal(exp3.categoryId,'cat_uncategorized');
});

