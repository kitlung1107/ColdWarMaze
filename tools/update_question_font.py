"""Rebuild the licensed font subset, retaining all existing glyphs."""
import argparse
import json
from pathlib import Path
import sys

parser=argparse.ArgumentParser()
parser.add_argument('--source-font',required=True)
parser.add_argument('--fonttools-path')
args=parser.parse_args()
if args.fonttools_path:sys.path.insert(0,args.fonttools_path)
from fontTools import subset
from fontTools.ttLib import TTFont

root=Path(__file__).resolve().parents[1]
target=root/'assets/ArchiveStudySans.otf'
existing=TTFont(target)
codepoints=set(existing.getBestCmap())
existing.close()
bank=json.loads((root/'data/questions.json').read_text(encoding='utf-8'))
visible=set()
for q in bank:
    texts=[q.get(k,'') for k in ('title','prompt','explanation','answer_text','pages')]+q.get('items',[])+q.get('options',[])
    visible.update(ord(c) for c in ''.join(texts) if not c.isspace())
for file in (root/'scripts').glob('*.gd'):
    codepoints.update(map(ord,file.read_text(encoding='utf-8')))
print('New question glyphs needed:',len(visible-codepoints))
codepoints.update(visible)
font=TTFont(args.source_font)
missing=visible-set(font.getBestCmap())
assert not missing,sorted(missing)
options=subset.Options();options.layout_features=['*']
worker=subset.Subsetter(options=options)
worker.populate(unicodes=codepoints);worker.subset(font)
for entry in font['name'].names:
    if entry.nameID in (1,4,6,16):entry.string='ArchiveStudySans'.encode(entry.getEncoding())
    elif entry.nameID in (2,17):entry.string='Regular'.encode(entry.getEncoding())
font.save(target)
assert visible<=set(TTFont(target).getBestCmap())
print('PASS: all 400 questions covered by font; existing glyphs retained')
