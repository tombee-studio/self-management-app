"""Validate existing PNG dimensions, manifest references and iOS opacity."""
import json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parent.parent
master=Image.open(root/'assets/icon/app_icon_master.png')
assert master.width==master.height
count=0
for asset in json.loads((root/'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())['images']:
    path=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'/asset['filename']
    image=Image.open(path)
    px=round(float(asset['size'].split('x')[0])*float(asset['scale'].rstrip('x')))
    assert image.size==(px,px), str(path)
    assert image.convert('RGBA').getextrema()[3]==(255,255), str(path)
    count+=1
for density,px in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    path=root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    assert Image.open(path).size==(px,px), str(path)
    count+=1
assert '@mipmap/ic_launcher' in (root/'android/app/src/main/AndroidManifest.xml').read_text()
print(f'PASS: {count} icon variants, dimensions/references/opacity; installed visual review remains required')
