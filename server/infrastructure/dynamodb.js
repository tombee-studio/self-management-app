'use strict';
const {fail}=require('../domain/model');
class DynamoStore {
 constructor(client,commands,tables,deadline=()=>false) {Object.assign(this,{client,commands,tables,deadline});}
 async get(owner,table,id) {
  const result=await this.client.send(new this.commands.GetCommand({TableName:this.tables[table],Key:{ownerId:owner,id},ConsistentRead:true}));
  return result.Item?.data??null;
 }
 async generation(owner){return (await this.get(owner,'metadata','generation'))?.value||0;}
 async all(owner,table) {
  let ExclusiveStartKey;const items=[];
  do {
   if(this.deadline())fail('Busy');
   const result=await this.client.send(new this.commands.QueryCommand({TableName:this.tables[table],KeyConditionExpression:'ownerId = :owner',ExpressionAttributeValues:{':owner':owner},ConsistentRead:true,ExclusiveStartKey}));
   items.push(...(result.Items||[]).map(x=>x.data));ExclusiveStartKey=result.LastEvaluatedKey;
  }while(ExclusiveStartKey);
  return items;
 }
 async load(owner) {
  const [catalog,budget,expenses]=await Promise.all([this.get(owner,'categories','catalog'),this.get(owner,'budgets','current'),this.all(owner,'expenses')]);
  return {catalog,budget,expenses};
 }
 async deliver(owner,receiptId,event,writes) {
  const entries=[...writes,{table:'metadata',id:receiptId,data:{eventId:event.eventId}},
   {table:'events',id:event.eventId,data:{...event,deliveryState:'delivered'}}];
  const operations=entries.map(entry=>({Put:{TableName:this.tables[entry.table],Item:{ownerId:owner,id:entry.id,data:entry.data},...(entry.id===receiptId?{ConditionExpression:'attribute_not_exists(ownerId)'}:{})}}));
  if(operations.length>20||Buffer.byteLength(JSON.stringify(operations))>1024*1024)fail('PayloadTooLarge');
  try {await this.client.send(new this.commands.TransactWriteCommand({TransactItems:operations}));}
  catch(error) {
   if(error.name==='TransactionCanceledException' && await this.get(owner,'metadata',receiptId))return;
   throw error;
  }
 }
 async commit(owner,snapshot,changes,events,changed) {
  const operations=[];
  const condition=(table,id,version,field='version')=>({TableName:this.tables[table],Key:{ownerId:owner,id},ConditionExpression:version?'#d.#v = :v':'attribute_not_exists(ownerId)',...(version?{ExpressionAttributeNames:{'#d':'data','#v':field},ExpressionAttributeValues:{':v':version}}:{})});
  const generationCondition=condition('metadata','generation',snapshot.generation,'value');
  if(changed) {
   operations.push({Put:{...generationCondition,Item:{ownerId:owner,id:'generation',data:{value:snapshot.generation+1}}}});
   delete operations.at(-1).Put.Key;
  } else operations.push({ConditionCheck:generationCondition});
  // Every command checks the catalog version it observed, including expense references.
  if(snapshot.catalog&&!changes.some(x=>x.table==='categories'))operations.push({ConditionCheck:condition('categories','catalog',snapshot.catalog.version)});
  for(const change of changes) {
   const Item={ownerId:owner,id:change.id,data:change.data};
   if(['categories','budgets'].includes(change.table)&&Buffer.byteLength(JSON.stringify(Item))>150*1024)fail('PayloadTooLarge');
   let expected;
   if(change.table==='categories')expected=snapshot.catalog?.version;
   if(change.table==='budgets')expected=snapshot.budget?.version;
   if(change.table==='expenses')expected=snapshot.expenses.find(e=>e.id===change.id)?.version;
   const put={TableName:this.tables[change.table],Item};
   if(['expenses','categories','budgets'].includes(change.table)) {
    const c=condition(change.table,change.id,expected);delete c.Key;Object.assign(put,c);
   }else if(change.id.startsWith('event-consumer#')||change.id.startsWith('receipt#')||change.id.startsWith('external#')||change.id.startsWith('notification#'))put.ConditionExpression='attribute_not_exists(ownerId)';
   operations.push({Put:put});
  }
  for(const event of events)operations.push({Put:{TableName:this.tables.events,Item:{ownerId:owner,id:event.eventId,data:{...event,deliveryState:'pending'}},ConditionExpression:'attribute_not_exists(ownerId)'}});
  if(operations.length>20||Buffer.byteLength(JSON.stringify(operations))>1024*1024)fail('PayloadTooLarge');
  const keys=operations.map(x=>{const v=x.Put||x.ConditionCheck;return v.TableName+'/'+(v.Item||v.Key).id;});
  if(new Set(keys).size!==keys.length)throw new Error('Duplicate transaction item');
  try {await this.client.send(new this.commands.TransactWriteCommand({TransactItems:operations}));}
  catch(e) {if(e.name==='TransactionCanceledException'||e.name==='ConditionalCheckFailedException')fail('VersionConflict');throw e;}
 }
}
module.exports={DynamoStore};
