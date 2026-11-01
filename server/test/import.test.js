const {test}=require('node:test');const assert=require('node:assert/strict');const sdk=require('@aws-sdk/lib-dynamodb');const {importCloud}=require('../../tool/import_cloud.cjs');const {migrate}=require('../infrastructure/migration');
test('cloud import verifies totals and rolls back all target rows after an unknown transaction outcome',async()=>{
 const plan=migrate({ownerId:'o',categories:[],expenses:[{expense_id:'e',amount:123,category_id:'missing',spent_at:'2026-11-01T00:00:00Z'}]},'o');
 const tables={expenses:'e',categories:'c',budgets:'b',metadata:'m',events:'v'};const records=new Map();let lose=false;
 const client={send:async c=>{
  const p=c.input;
  if(c instanceof sdk.GetCommand)return {Item:records.get(p.TableName+'/'+p.Key.id)};
  if(c instanceof sdk.QueryCommand)return {Items:[...records].filter(([k])=>k.startsWith(p.TableName+'/')).map(([,v])=>v)};
  for(const op of p.TransactItems){if(op.Put)records.set(op.Put.TableName+'/'+op.Put.Item.id,op.Put.Item);else records.delete(op.Delete.TableName+'/'+op.Delete.Key.id);}
  if(lose&&p.TransactItems.some(x=>x.Put)){lose=false;throw Error('response lost after commit');}return {};
 }};
 assert.equal((await importCloud(plan,tables,client)).total,123);await assert.rejects(importCloud(plan,tables,client),/must be empty/);
 records.clear();lose=true;await assert.rejects(importCloud(plan,tables,client),/response lost/);assert.equal(records.size,0);
});
