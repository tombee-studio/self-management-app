"""Dependency and artifact checks. Exits nonzero with the offending path."""
from pathlib import Path
import re
import json
errors = []
for p in Path('lib').rglob('*.dart'):
    for text in ['package:drift', 'package:sqlite', '/database/', 'sync/push', 'sync/pull', 'SyncOutbox']:
        if text in p.read_text():
            errors.append(f'{p}: forbidden device persistence/sync dependency {text}')
for p in Path('server/domain').rglob('*.js'):
    for text in ['@aws-sdk', 'flutter', '../infrastructure', '../api', 'node:http']:
        if text in p.read_text():
            errors.append(f'{p}: forbidden Domain dependency {text}')
for p in Path('server/contracts').glob('*.json'):
    if p.read_bytes() != (Path('docs/spec/contracts') / p.name).read_bytes():
        errors.append(f'{p}: contract drift')
dart_contract = re.search(r"r'''([\s\S]*?)'''", Path('lib/cloud/contracts.dart').read_text())
if not dart_contract or json.loads(dart_contract[1]) != json.loads(Path('docs/spec/contracts/shared.schema.json').read_text()):
    errors.append('lib/cloud/contracts.dart: contract drift')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: no device DB/sync, Domain dependency violations, or server contract drift')
