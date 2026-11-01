"""Sync checked-in contracts without altering the canonical SPEC."""
import json
import pathlib
import re
root = pathlib.Path(__file__).resolve().parent.parent
for name in ['shared.schema.json', 'events.schema.json']:
    (root / 'server/contracts' / name).write_bytes((root / 'docs/spec/contracts' / name).read_bytes())
path = root / 'lib/cloud/contracts.dart'
source = path.read_text()
encoded = json.dumps(json.loads((root / 'docs/spec/contracts/shared.schema.json').read_text()), ensure_ascii=False, separators=(',', ':'))
source = re.sub(r"r'''[\s\S]*?'''", lambda _: "r'''" + encoded + "'''", source, count=1)
path.write_text(source)
