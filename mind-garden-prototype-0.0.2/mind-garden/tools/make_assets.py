"""Original placeholder pixel assets. Python 3 + Pillow, no external images."""
from pathlib import Path
from PIL import Image, ImageDraw
import random, math, wave, struct

ROOT = Path(__file__).resolve().parents[1] / 'assets'
ROOT.mkdir(exist_ok=True)
P = {'sky':'#283749','earth':'#344b49','grass':'#435e52','light':'#62785a',
     'dark':'#192e35','leaf':'#36564e','leaf2':'#4d7060','leaf3':'#738269',
     'water':'#274f5c','shine':'#648c8f','stone':'#6e7a7b','stone2':'#48585f',
     'wood':'#73614e','wood2':'#ab8a60','gold':'#e8b66f','pink':'#bb879e'}

# Plant sprite sheet, 4 phases. Old flowers leave seeds, they are not punishments.
im=Image.new('RGBA',(96,32));d=ImageDraw.Draw(im)
for s in range(4):
    x=s*24+12;d.ellipse((x-7,26,x+7,30),fill='#253b38')
    if s==0:
        rect(d,(x,19,x+1,27),'#87a477');rect(d,(x-4,18,x,20),'#9aba85');rect(d,(x+2,16,x+5,18),'#749972')
    elif s in (1,2):
        rect(d,(x,10,x+1,27),'#7e9a70');rect(d,(x-6,18,x-1,20),'#739a71');rect(d,(x+2,15,x+6,17),'#97ae7a')
        color='#bc8fab' if s==1 else '#e1b475'
        for dx,dy in [(-3,0),(3,0),(0,-3),(0,3)]:rect(d,(x+dx-2,8+dy-2,x+dx+2,8+dy+2),color)
        rect(d,(x-1,7,x+1,9),'#f4d49a')
    else:
        rect(d,(x,13,x+1,27),'#9a9b70');rect(d,(x-2,11,x+3,15),'#cfbd83')
        for dx,dy in [(-6,23),(5,25),(3,20)]:rect(d,(x+dx,dy,x+dx+2,dy+1),'#d5ba7d')
im.save(ROOT/'plants.png')

# A soft, original synthetic singing-bowl approximation. Replace with a licensed
# recording after sound direction is approved. Peak is deliberately low.
rate=22050;duration=5.0
with wave.open(str(ROOT/'bowl.wav'),'wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate)
    out=bytearray()
    for n in range(int(rate*duration)):
        t=n/rate;attack=min(1,t/.008);release=min(1,(duration-t)/.3)
        v=sum(a*math.sin(math.tau*f*t)*math.exp(-t/decay) for f,a,decay in [(440,.32,2.8),(887,.13,1.9),(1229,.055,1.2),(1765,.025,.8)])
        out.extend(struct.pack('<h',int(24000*v*attack*release)))
    w.writeframes(out)
print('Regenerated the small plant atlas and synthetic bowl')
