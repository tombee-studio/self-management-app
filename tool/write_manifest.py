"""Record the exact implementation and test sources for a local verification run."""
import hashlib
import json
import sys
import subprocess
from pathlib import Path

sources=[]
for directory in ['lib','server','test','integration_test','tool','terraform','ios/Runner','android/app/src/main']:
    for path in Path(directory).rglob('*'):
        if not path.is_file() or 'node_modules' in path.parts or '.terraform' in path.parts:
            continue
        if path.suffix in {'.dart','.js','.cjs','.py','.json','.yaml','.tf','.swift','.kt','.xml','.png','.plist','.rb'}:
            sources.append(path)
for name in ['pubspec.yaml','pubspec.lock','android/settings.gradle.kts','android/app/build.gradle.kts','android/gradle/wrapper/gradle-wrapper.properties','ios/Podfile','ios/Podfile.lock','ios/Runner.xcodeproj/project.pbxproj','server/package-lock.json']:
    sources.append(Path(name))
manifest={
    'dateJST':'2026-11-02',
    'baseCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    'target':'working tree including pre-existing untracked implementation',
    'environment':{'macOS':'27.0.1','Flutter':'3.47.7','Dart':'3.13.5','Node':'24.2.0','Terraform':'1.15.2'},
    'commands':['flutter analyze','flutter test','npm test --prefix server','python3 tool/check_architecture.py','python3 tool/check_icons.py','terraform -chdir=terraform validate','flutter build ios --simulator --debug','flutter build apk --debug'],
    'unperformed':['production migration/cutover (outside staging scope)','real Wallet/physical lock-screen behavior (simulator excluded)','monthly actual bill/JPY target','remaining individual variants of the 99 mandatory cases'],
    'sha256':{str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(set(sources)) if path.exists()}
}
Path(sys.argv[1] if len(sys.argv)>1 else 'docs/verification/results/evidence/2026-11-02/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
