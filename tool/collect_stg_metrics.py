"""Collect measured staging usage without reading other applications' billing data."""
import datetime
import json
from pathlib import Path
import subprocess
config=json.loads(Path('/private/tmp/iris-stg-config.json').read_text())
assert config['environment']=='stg'
end=datetime.datetime.now(datetime.timezone.utc);start=end-datetime.timedelta(hours=1)
queries=[('AWS/Lambda',metric,'FunctionName','iris-sync-handler-stg',stat) for metric,stat in [('Invocations','Sum'),('Errors','Sum'),('Duration','Average'),('Duration','Maximum')]]
queries += [('AWS/DynamoDB',metric,'TableName',table,'Sum') for table in config['tables'].values() for metric in ['ConsumedReadCapacityUnits','ConsumedWriteCapacityUnits']]
results=[]
for namespace,metric,dimension,target,stat in queries:
    command=['aws','cloudwatch','get-metric-statistics','--namespace',namespace,'--metric-name',metric,'--dimensions',f'Name={dimension},Value={target}','--start-time',start.isoformat(),'--end-time',end.isoformat(),'--period','60','--statistics',stat,'--region','ap-northeast-1','--output','json']
    data=json.loads(subprocess.check_output(command,text=True))
    values=[p[stat] for p in data['Datapoints']]
    measured=(max(values) if stat=='Maximum' else sum(values)/len(values) if stat=='Average' else sum(values)) if values else None
    results.append({'namespace':namespace,'metric':metric,'target':target,'statistic':stat,'measured':measured,'datapoints':len(values),'unit':data['Datapoints'][0]['Unit'] if values else None})
Path('/private/tmp/iris-stg-metrics.json').write_text(json.dumps({'environment':'stg','start':start.isoformat(),'end':end.isoformat(),'results':results,'note':'Measured usage; monthly bill/JPY target is not proven by a short staging run.'},indent=2)+'\n')
print(json.dumps(results[:4],indent=2))
