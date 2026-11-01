'use strict';
const schema=require('../contracts/shared.schema.json');
const {fail,graphemes}=require('../domain/model');
// Evaluates the vocabulary used by the checked-in contract, including grapheme limits.
function matches(value,s) {
 if(s.$ref)return matches(value,schema.$defs[s.$ref.split('/').pop()]);
 if(s.oneOf)return s.oneOf.filter(x=>matches(value,x)).length===1;
 if(s.anyOf)return s.anyOf.some(x=>matches(value,x));
 if('const'in s&&value!==s.const)return false;
 if(s.enum&&!s.enum.includes(value))return false;
 if(s.type) { const types=Array.isArray(s.type)?s.type:[s.type]; if(!types.some(t=>t==='null'?value===null:t==='array'?Array.isArray(value):t==='object'?value!==null&&typeof value==='object'&&!Array.isArray(value):t==='integer'?Number.isSafeInteger(value):typeof value===t))return false; }
 if(typeof value==='string') {
 if(s.minLength!==undefined&&value.length<s.minLength)return false;
 if(s.pattern&&!new RegExp(s.pattern).test(value))return false;
 if(s['x-graphemeMaxLength']&&graphemes(value).length>s['x-graphemeMaxLength'])return false;
 if(s.format==='uuid'&&!/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(value))return false;
 if(s.format==='date-time'&&value.length>=10) {const date=value.slice(0,10);if(!Number.isFinite(Date.parse(date))||new Date(date).toISOString().slice(0,10)!==date)return false;}
 if(s.format==='date-time'&&(!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$/.test(value)||!Number.isFinite(Date.parse(value))))return false;
 if(s.format==='date'&&(!Number.isFinite(Date.parse(value))||new Date(value).toISOString().slice(0,10)!==value))return false;
 }
 if(typeof value==='number'&&((s.minimum!==undefined&&value<s.minimum)||(s.maximum!==undefined&&value>s.maximum)))return false;
 if(Array.isArray(value)) {
 if(s.maxItems!==undefined&&value.length>s.maxItems)return false;
 if(s.uniqueItems&&new Set(value.map(x=>JSON.stringify(x))).size!==value.length)return false;
 if(s.items&&!value.every(x=>matches(x,s.items)))return false;
 }
 if(value&&typeof value==='object'&&!Array.isArray(value)) {
 if(s.required?.some(k=>!(k in value)))return false;
 if(s.minProperties&&Object.keys(value).length<s.minProperties)return false;
 if(s.additionalProperties===false&&Object.keys(value).some(k=>!Object.hasOwn(s.properties||{},k)))return false;
 if(Object.entries(s.properties||{}).some(([k,v])=>k in value&&!matches(value[k],v)))return false;
 }
 return true;
}
function validate(value,name) {if(!matches(value,schema.$defs[name]))fail(value?.schemaVersion!==undefined&&value.schemaVersion!==3?'UnsupportedVersion':'ValidationFailed');}
module.exports={matches,validate};
