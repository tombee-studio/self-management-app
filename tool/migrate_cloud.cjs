// Offline preparation only. Import into isolated v3 tables after stopping legacy writes.
const fs=require('node:fs');const {migrate}=require('../server/infrastructure/migration');
const [backupPath,ownerId,outputPath]=process.argv.slice(2);
if(!backupPath||!ownerId||!outputPath)throw new Error('Usage: node tool/migrate_cloud.cjs backup.json ownerId output.json');
const backup=JSON.parse(fs.readFileSync(backupPath,'utf8'));const result=migrate(backup,ownerId);
fs.writeFileSync(outputPath,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({count:result.manifest.count,total:result.manifest.total,backupDigest:result.backupDigest}));
