"""QA only: inspect alpha/manifest and compose evidence; never edits kit assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
QA = Path(__file__).resolve().parent
KIT = ROOT / 'assets/generated/sprites/building-kit'
BASELINE = Path('/tmp/codex-kit/before')
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 17)


def contact_sheet(folder, phase):
    pieces = json.loads((folder / 'building_kit.json').read_text())['pieces']
    plate_path = QA / 'after-field-ground.png'
    plate = Image.open(plate_path if plate_path.exists() else QA / 'before-field-ground.png').convert('RGBA')
    sheet = Image.new('RGBA', (2400, 2280))
    for index, (name, entry) in enumerate(pieces.items()):
        x, y = index % 6 * 400, index // 6 * 380
        cell = plate.crop((440, 260, 840, 640))
        img = Image.open(folder / entry['file']).convert('RGBA')
        scale = min(4, 368 / img.width, 330 / img.height)
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.Resampling.LANCZOS)
        cell.alpha_composite(img, ((400-img.width)//2, 35+(335-img.height)//2))
        draw = ImageDraw.Draw(cell)
        draw.rectangle((0, 0, 400, 32), fill=(15, 18, 23, 240))
        draw.text((9, 6), f'{name}  ({scale:.2f}x)', font=FONT, fill='white')
        sheet.alpha_composite(cell, (x, y))
    sheet.convert('RGB').save(QA / f'{phase}-pieces-contact-sheet.png')


def seam_sheet(folder, phase, name):
    tile = Image.open(folder / (name + '.png')).convert('RGBA')
    canvas = Image.new('RGBA', (288, 176))
    count = [0] * (canvas.width * canvas.height)
    for row in range(4):
        for col in range(4):
            left, top = 112 + (col-row)*32, 12 + (col+row)*16
            canvas.alpha_composite(tile, (left, top))
            for y in range(tile.height):
                for x in range(tile.width):
                    if tile.getpixel((x,y))[3] >= 128:
                        count[(top+y)*canvas.width+left+x] += 1
    mask = Image.new('L', canvas.size)
    for y in range(128):
        for x in range(256):
            if abs((x+0.5)-128)/128 + abs((y+1.0)-64)/64 < 1:
                mask.putpixel((x+16, y+12),255)
    holes = sum(v == 0 and m > 0 for v, m in zip(count, mask.tobytes()))
    overlaps = sum(v > 1 for v in count)
    background = Image.new('RGBA', canvas.size, (52, 22, 65, 255))
    background.alpha_composite(canvas)
    background.resize((1152, 704), Image.Resampling.NEAREST).save(QA / f'{phase}-{name}-seams-4x4.png')
    return {'opaque_bbox': tile.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox(),
            'interior_gaps': holes, 'overlapping_opaque_pixels': overlaps}


def comparisons():
    for layout in ['tavern', 'shop', 'cottage', 'warehouse']:
        sheet = Image.new('RGB', (1920, 990), (15, 18, 23))
        draw = ImageDraw.Draw(sheet)
        for row, phase in enumerate(['before','after']):
            for col, state in enumerate(['outside','walls-up','inside']):
                path = QA / f'{phase}-{layout}-{state}.png'
                if not path.exists():
                    continue
                image = Image.open(path).convert('RGB').resize((640,450),Image.Resampling.LANCZOS)
                x, y = col*640, row*495
                draw.text((x+12,y+12),f'{phase} / {layout} / {state}',font=FONT,fill='white')
                sheet.paste(image,(x,y+45))
        # Two rows of matched cameras; no crops or retouching.
        sheet.save(QA / f'compare-{layout}.png')


def inspect():
    manifest = json.loads((KIT/'building_kit.json').read_text())
    old = json.loads((QA/'baseline-manifest.json').read_text())
    checks = {'piece_count':len(manifest['pieces']), 'pieces':{}, 'floors':{}}
    checks['unchanged_piece_list'] = set(old['pieces']) == set(manifest['pieces']) if old else None
    for name, entry in manifest['pieces'].items():
        image = Image.open(KIT/entry['file']).convert('RGBA')
        alpha = image.getchannel('A')
        checks['pieces'][name] = {'size_matches_manifest': list(image.size)==entry['size'],
            'alpha_extrema':alpha.getextrema(), 'transparent_pixels':alpha.histogram()[0],
            'opaque_pixels':alpha.histogram()[255],
            'pivot_unchanged': entry['pivot']==old['pieces'][name]['pivot']}
        if (BASELINE/entry['file']).exists():
            prev = Image.open(BASELINE/entry['file']).convert('RGBA')
            checks['pieces'][name]['alpha_unchanged'] = image.size==prev.size and ImageChops.difference(alpha,prev.getchannel('A')).getbbox() is None
    for name in ['floor-planks','floor-footing']:
        checks['floors'][name] = seam_sheet(KIT,'after',name)
        if (BASELINE/(name+'.png')).exists():
            seam_sheet(BASELINE,'before',name)
    contact_sheet(KIT,'after')
    if (BASELINE/'building_kit.json').exists():
        contact_sheet(BASELINE,'before')
    comparisons()
    (QA/'asset-checks.json').write_text(json.dumps(checks,indent=2)+'\n')
    print(json.dumps({k:v for k,v in checks.items() if k!='pieces'},indent=2))
    print('ALPHA:',sum(p['alpha_extrema']==(0,255) for p in checks['pieces'].values()),'/ 36 pieces have transparency and opaque paint')
    assert checks['piece_count'] == 36 and checks['unchanged_piece_list']
    assert {p.name for p in KIT.glob('*.png')} == {p['file'] for p in manifest['pieces'].values()}
    assert manifest['spec'] == old['spec']
    assert all(p['size_matches_manifest'] and p['pivot_unchanged'] and p['alpha_extrema']==(0,255) for p in checks['pieces'].values())
    assert all(p['opaque_bbox']==(0,0,64,31) and p['interior_gaps']==0 and p['overlapping_opaque_pixels']==0 for p in checks['floors'].values())
    print('KIT-ASSET-CHECK: PASS (36 pieces; exact floor diamonds; zero gaps/overlaps; all pivots/spec unchanged)')


if __name__ == '__main__':
    inspect()
