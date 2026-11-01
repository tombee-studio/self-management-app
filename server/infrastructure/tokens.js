'use strict';
const {createHmac,createHash,timingSafeEqual}=require('node:crypto');
const {fail}=require('../domain/model');
function canonical(value) {
 if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
 if(value&&typeof value==='object')return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
 return JSON.stringify(value);
}
class Tokens {
 constructor(secret,clock=()=>Date.now()) {if(!secret||secret.length<32)throw new Error('A persistent signing secret of at least 32 characters is required');this.secret=secret;this.clock=clock;}
 hash(value){return createHash('sha256').update(canonical(value)).digest('hex');}
 mac(value){return createHmac('sha256',this.secret).update(value).digest('base64url');}
 sign(value){const body=Buffer.from(JSON.stringify({...value,expires:this.clock()+900000})).toString('base64url');return body+'.'+this.mac(body);}
 verify(token){try {
  const [body,signature,...rest]=token.split('.');if(rest.length||!signature)throw new Error();
  const actual=Buffer.from(signature),expected=Buffer.from(this.mac(body));
  if(actual.length!==expected.length||!timingSafeEqual(actual,expected))throw new Error();
  const value=JSON.parse(Buffer.from(body,'base64url'));if(value.expires<=this.clock())throw new Error();return value;
 }catch{fail('CursorInvalidated');}}
}
module.exports={Tokens,canonical};
