'use strict';
const {fail}=require('../domain/model');
class MemoryStore {
 constructor(){this.tables={expenses:new Map(),categories:new Map(),budgets:new Map(),metadata:new Map(),events:new Map()};this.writes=0;this.beforeCommit=null;this.afterCommit=null;}
 async get(owner,table,id){return structuredClone(this.tables[table].get(owner+'/'+id)||null);}
 async all(owner,table){return [...this.tables[table]].filter(([id])=>id.startsWith(owner+'/')).map(([,e])=>structuredClone(e));}
 async generation(owner){return (await this.get(owner,'metadata','generation'))?.value||0;}
 async load(owner){return {catalog:await this.get(owner,'categories','catalog'),budget:await this.get(owner,'budgets','current'),expenses:[...this.tables.expenses].filter(([id])=>id.startsWith(owner+'/')).map(([,e])=>structuredClone(e))};}
 async deliver(owner,receiptId,event,writes) {
  if(this.beforeCommit)await this.beforeCommit();
  if(this.tables.metadata.has(owner+'/'+receiptId))return;
  const next=structuredClone(this.tables);
  for(const change of [...writes,{table:'metadata',id:receiptId,data:{eventId:event.eventId}},{table:'events',id:event.eventId,data:{...event,deliveryState:'delivered'}}])next[change.table].set(owner+'/'+change.id,structuredClone(change.data));
  this.tables=next;this.writes++;
  if(this.afterCommit)await this.afterCommit();
 }
 async commit(owner,s,changes,events,changed){
  if(this.beforeCommit)await this.beforeCommit();
  if((this.tables.metadata.get(owner+'/generation')?.value||0)!==s.generation)fail('VersionConflict');
  for(const change of changes){if((change.id.startsWith('receipt#')||change.id.startsWith('event-consumer#'))&&this.tables.metadata.get(owner+'/'+change.id))fail('VersionConflict');}
  const next=structuredClone(this.tables);
  for(const change of changes)next[change.table].set(owner+'/'+change.id,structuredClone(change.data));
  for(const event of events)next.events.set(owner+'/'+event.eventId,event);
  if(changed)next.metadata.set(owner+'/generation',{value:s.generation+1});
  this.tables=next;this.writes++;
  if(this.afterCommit)await this.afterCommit();
 }
}
module.exports={MemoryStore};
