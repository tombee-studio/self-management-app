'use strict';
// Explicit administrative invocation only; the app never migrates or uploads device data.
const fs=require('node:fs');const {DynamoDBClient}=require('../server/node_modules/@aws-sdk/client-dynamodb');const sdk=require('../server/node_modules/@aws-sdk/lib-dynamodb');
const {DynamoStore}=require('../server/infrastructure/dynamodb');
async function importCloud(plan,tables,client){
 const store=new DynamoStore(client,sdk,tables),owner=plan.ownerId;
 for(const table of ['expenses','categories','budgets','metadata','events'])if((await store.all(owner,table)).length)throw Error('Target owner must be empty');
 try {
  for(let n=0;n<plan.rows.length;n+=20){await client.send(new sdk.TransactWriteCommand({TransactItems:plan.rows.slice(n,n+20).map(r=>({Put:{TableName:tables[r.table],Item:{ownerId:owner,id:r.id,data:r.data},ConditionExpression:'attribute_not_exists(ownerId)'}}))}));}
  const state=await store.load(owner);const live=state.expenses.filter(e=>!e.isDeleted);
  if(live.length!==plan.manifest.count||live.reduce((n,e)=>n+e.amount,0)!==plan.manifest.total||JSON.stringify(state.expenses.map(e=>e.id).sort())!==JSON.stringify(plan.manifest.ids)||JSON.stringify(state.catalog.categories.map(c=>c.id).sort())!==JSON.stringify(plan.manifest.categoryIds))throw Error('Post-migration comparison failed');
  return plan.manifest;
 }catch(error){
  // Includes requests with lost responses; legacy tables and their backup remain untouched.
  for(let n=0;n<plan.rows.length;n+=20)await client.send(new sdk.TransactWriteCommand({TransactItems:plan.rows.slice(n,n+20).map(r=>({Delete:{TableName:tables[r.table],Key:{ownerId:owner,id:r.id}}}))}));
  throw error;
 }
}
module.exports={importCloud};
if(require.main===module){
 const [planPath,tablesPath,ack]=process.argv.slice(2);
 if(ack!=='--legacy-writes-stopped')throw Error('Confirm stopped legacy writes; usage: node tool/import_cloud.cjs plan.json tables.json --legacy-writes-stopped');
 const plan=JSON.parse(fs.readFileSync(planPath));const tables=JSON.parse(fs.readFileSync(tablesPath));
 importCloud(plan,tables,sdk.DynamoDBDocumentClient.from(new DynamoDBClient({}))).then(result=>console.log(JSON.stringify(result))).catch(error=>{console.error(error.name+': '+error.message);process.exitCode=1;});
}
