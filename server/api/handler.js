'use strict';
const {validate}=require('./schema');
const {DomainError,fail}=require('../domain/model');
const status={ValidationFailed:400,InvariantViolation:400,UnsupportedVersion:400,OwnerMismatch:403,NotFound:404,VersionConflict:409,Busy:409,CursorInvalidated:409,UndoExpired:410,PayloadTooLarge:413,StorageFailure:500,TransportFailure:503};
function createHandler(service,ownerId) {
 return async event=>{
  const respond=(statusCode,body)=>({statusCode,headers:{'content-type':'application/json','cache-control':'no-store'},body:JSON.stringify(body)});
  try {
   const method=event.requestContext?.http?.method||event.httpMethod;
   const path=event.rawPath||event.path;
   if(method==='GET'&&path==='/health')return respond(200,{status:'ok',schemaVersion:3});
   if(!['/commands','/queries','/payment'].includes(path))Deny();
   const raw=event.isBase64Encoded?Buffer.from(event.body||'','base64').toString():event.body||'{}';
   if(Buffer.byteLength(raw)>1024*1024)fail('PayloadTooLarge');
   let body;
   try {body=method==='GET'?(event.queryStringParameters||{}):JSON.parse(raw);}catch{fail('ValidationFailed');}
   const headers=Object.fromEntries(Object.entries(event.headers||{}).map(([k,v])=>[k.toLowerCase(),v]));
   const owner=headers['x-user-id']||body.user_id;
   if(!owner)fail('OwnerMismatch');
   if(owner!==ownerId||(body.user_id&&body.user_id!==owner))fail('OwnerMismatch');
   let result;
   if(path==='/payment') {
    if(!['GET','POST'].includes(method))Deny();
    if(method==='POST'&&Object.keys(event.queryStringParameters||{}).length)fail('ValidationFailed');
    validate(body,'PaymentInput');
    result=await service.command(owner,{operation:'IngestPayment',requestId:body.requestId,input:body},true);
    validate(result,'PaymentResponse');
   }else {
    if(method!=='POST')Deny();
    validate(body,path==='/commands'?'CommandRequest':'QueryRequest');
    result=path==='/commands'?await service.command(owner,body):await service.query(owner,body);
    validate(result,path==='/commands'?'CommandResponse':'QueryResponse');
   }
   if(Buffer.byteLength(JSON.stringify(result))>5*1024*1024)fail('Busy');
   return respond(200,result);
  }catch(e) {
   const code=e instanceof DomainError?e.code:'StorageFailure';
   return respond(status[code]||500,{error:code,retryable:['Busy','StorageFailure','TransportFailure'].includes(code),...(e.field?{field:e.field}:{})});
  }
 };
}
function Deny(){fail('NotFound');}
module.exports={createHandler};
