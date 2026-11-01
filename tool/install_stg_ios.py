"""Install the regular stg-configured entry point and verify a cold relaunch."""
import json
from pathlib import Path
import re
import subprocess
import time
config=json.loads(Path('/private/tmp/iris-stg-config.json').read_text());assert config['environment']=='stg'
phone='0E857380-788D-4B8E-B66E-2A8305620CA8';tablet='089A858E-80C6-4224-8B93-16128634E655'
with Path('/private/tmp/iris-stg-regular-build.log').open('w') as log:
    subprocess.run(['flutter','build','ios','--simulator','--debug','-t','lib/main.dart','--dart-define=IRIS_API_ENDPOINT='+config['endpoint'].rstrip('/'),'--dart-define=IRIS_OWNER_ID='+config['owner']],stdout=log,stderr=log,check=True)
results=[]
for device,label in [(phone,'ios'),(tablet,'ipad')]:
    subprocess.run(['xcrun','simctl','install',device,'build/ios/iphonesimulator/Runner.app'],check=True)
    first=subprocess.check_output(['xcrun','simctl','launch',device,'com.tombee-studio.irisApp'],text=True).strip()
    time.sleep(8)
    subprocess.run(['xcrun','simctl','io',device,'screenshot',f'/private/tmp/iris-stg-{label}-regular.png'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    subprocess.run(['xcrun','simctl','terminate',device,'com.tombee-studio.irisApp'],check=True)
    second=subprocess.check_output(['xcrun','simctl','launch',device,'com.tombee-studio.irisApp'],text=True).strip()
    assert re.search(r'\d+$',first)[0]!=re.search(r'\d+$',second)[0]
    time.sleep(8)
    subprocess.run(['xcrun','simctl','io',device,'screenshot',f'/private/tmp/iris-stg-{label}-relaunch.png'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    results.append({'device':device,'label':label,'firstLaunch':first,'coldRelaunch':second,'differentProcess':True})
Path('/private/tmp/iris-stg-cold-relaunch.json').write_text(json.dumps({'environment':'stg','endpoint':config['endpoint'],'results':results},indent=2)+'\n')
print('PASS: regular stg app installed and cold-relaunched on iPhone and iPad')
