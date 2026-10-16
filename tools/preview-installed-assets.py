import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw
spec=importlib.util.spec_from_file_location('installed',Path(__file__).with_name('import-installed-assets.py'))
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
a=m.Assets()
gallery=Image.new('RGB',(800,1200),'#777777'); draw=ImageDraw.Draw(gallery)
for n,ident in enumerate(range(350,550)):
    try: obj=a.appearance(1,ident)
    except StopIteration: continue
    info=m.fields(m.fields(obj[2][0])[3][0]); sprite=a.sprite(info[5][0])
    x=n%10*80; y=n//10*60
    gallery.paste(sprite,(x,y),sprite); draw.text((x,y+40),str(ident),fill='white')
gallery.save(m.ROOT/'runtime/installed-preview.png')
