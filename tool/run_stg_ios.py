"""Run actual Flutter integration on iOS Simulator against the dedicated stg API."""
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import uuid
import urllib.parse

config=json.loads(Path('/private/tmp/iris-stg-config.json').read_text())
assert config['environment']=='stg'
device=sys.argv[1] if len(sys.argv)>1 else '0E857380-788D-4B8E-B66E-2A8305620CA8'
tag='ipad' if len(sys.argv)>1 else 'ios'
run=uuid.uuid4().hex[:8]
command=['flutter','test','integration_test/stg_app_test.dart','-d',device,
         '--verbose','--dart-define=IRIS_API_ENDPOINT='+config['endpoint'].rstrip('/'),
         '--dart-define=IRIS_OWNER_ID='+config['owner'],
         '--dart-define=IRIS_STG_RUN='+run,
         '--dart-define=IRIS_STG_NATIVE_NOTIFICATION='+('true' if tag=='ipad' else 'false')]
native=Path('/private/tmp/iris-native-ui')
native.mkdir(exist_ok=True)
for name in ['NativeUI.swift','create.rb']:
    shutil.copy2(Path(__file__).parent/'native_ui'/name,native/name)
environment=os.environ.copy()
cocoapods=sorted(Path('/opt/homebrew/Cellar/cocoapods').glob('*/libexec'))
if cocoapods: environment['GEM_HOME']=str(cocoapods[-1])
subprocess.run(['ruby',str(native/'create.rb')],env=environment,check=True)
with Path('/private/tmp/iris-native-build.log').open('w') as buildlog:
    subprocess.run(['xcodebuild','build-for-testing','-project',str(native/'NativeUI.xcodeproj'),'-scheme','NativeUI','-destination','platform=iOS Simulator,id='+device,'-derivedDataPath',str(native/'build'),'CODE_SIGNING_ALLOWED=NO'],stdout=buildlog,stderr=buildlog,check=True)
subprocess.run(['xcrun','simctl','terminate',device,'com.tombee-studio.irisApp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
subprocess.run(['xcrun','simctl','uninstall',device,'com.tombee-studio.irisApp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
with Path('/private/tmp/iris-stg-'+tag+'.log').open('w') as log:
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
    for line in process.stdout:
        log.write(line);log.flush()
        if 'IRIS_READY_FOR_NATIVE_LINK' in line:
            query=urllib.parse.urlencode({'amount':'567','merchant':'Native Link STG '+run,'external_tx_id':'native-'+run,'requestId':str(uuid.uuid4())})
            subprocess.run(['xcrun','simctl','openurl',device,'iris://add-expense?'+query],check=True,stdout=log,stderr=log)
            with Path('/private/tmp/iris-stg-native-'+tag+'.log').open('w') as nativeLog:
                subprocess.run(['xcodebuild','test-without-building','-project',str(native/'NativeUI.xcodeproj'),'-scheme','NativeUI','-destination','platform=iOS Simulator,id='+device,'-derivedDataPath',str(native/'build'),'-parallel-testing-enabled','NO','-only-testing:NativeUI/NativeUI/'+('testAcceptOpenURLAndNotification' if tag=='ipad' else 'testAcceptOpenURL'),'CODE_SIGNING_ALLOWED=NO'],stdout=nativeLog,stderr=nativeLog,check=True)

        if 'IRIS_CAPTURE_STG_SCREENSHOT' in line:
            subprocess.run(['xcrun','simctl','io',device,'screenshot','/private/tmp/iris-stg-'+tag+'.png'],check=True,stdout=log,stderr=log)
        if line.lstrip().startswith(('STG_', 'IRIS_', 'The following', 'Expected:', 'Actual:')) or 'Xcode build done.' in line or 'All tests passed!' in line or 'Some tests failed.' in line:
            print(line.strip(),flush=True)
    code=process.wait()
raise SystemExit(code)
