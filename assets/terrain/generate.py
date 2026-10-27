#!/usr/bin/env python3
"""Original deterministic wasteland material and isometric prop textures.

Only visual artwork is generated here. Geometry, paths, obstacles, harvesting,
visibility, and placement remain defined by the simulation.
Run from any working directory with Python, NumPy, and Pillow.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent
RNG = np.random.default_rng(35000)


def noise(w, h, step, rng=RNG):
    small = rng.random((max(2, h // step + 2), max(2, w // step + 2)))
    return np.asarray(Image.fromarray((small * 255).astype('uint8')).resize((w, h), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0


def ground():
    w, h = 3072, 2048
    broad = noise(w, h, 150)
    middle = noise(w, h, 38)
    fine = noise(w, h, 7)
    grit = RNG.normal(0, 2.4, (h, w)).astype(np.float32)
    soil = (broad - .5) * 23 + (middle - .5) * 12 + (fine - .5) * 8 + grit
    yy, xx = np.mgrid[:h, :w]
    ochre = np.maximum(0, middle - .48) * 12
    shade = np.clip((np.roll(fine, 1, 1) - fine) * 6 + (np.roll(fine, 1, 0) - fine) * 5, -4, 4)
    arr = np.stack((92 + soil + ochre + shade, 91 + soil + shade, 70 + soil * .82 + shade), axis=-1)
    # Same existing east-west transport corridor, now worn asphalt over gravel.
    edge = noise(w, 8, 32)[0] * 9 - 4
    road_dist = np.abs(yy - (1024 + edge[None, :]))
    verge = np.clip((47 - road_dist) / 10, 0, 1)
    road = np.clip((34 - road_dist) / 3, 0, 1)
    rough = (middle - .5) * 9 + grit * .8
    gravel = np.stack((73 + rough, 73 + rough, 62 + rough), axis=-1)
    asphalt = np.stack((66 + rough, 68 + rough, 61 + rough), axis=-1)
    arr = arr * (1-verge[...,None]) + gravel * verge[...,None]
    arr = arr * (1-road[...,None]) + asphalt * road[...,None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype('uint8')).convert('RGBA')
    decals = Image.new('RGBA', im.size)
    d = ImageDraw.Draw(decals, 'RGBA')
    # Fine gravel and isolated embedded stones, never movement-blocking objects.
    for i in range(26000):
        x, y = int(RNG.integers(w)), int(RNG.integers(h))
        r = int(RNG.choice([1, 1, 1, 1, 2, 2]))
        dark = (31, 34, 28, int(RNG.integers(30, 80)))
        d.ellipse((x-r, y, x+r+1, y+r+1), fill=dark)
        d.line((x-r, y, x, y-1), fill=(164, 156, 122, int(RNG.integers(35, 90))), width=1)
    # Broken veins and dry cracks: irregular, sparse, and at multiple scales.
    for i in range(550):
        x, y = float(RNG.integers(w)), float(RNG.integers(h))
        if abs(y-1024) < 48:
            continue
        pts = [(x, y)]
        angle = float(RNG.uniform(0, math.tau))
        for j in range(int(RNG.integers(3, 9))):
            angle += float(RNG.normal(0, .5))
            x += math.cos(angle)*float(RNG.uniform(3, 10))
            y += math.sin(angle)*float(RNG.uniform(3, 10))
            pts.append((x, y))
        d.line([(a+1, b+1) for a,b in pts], fill=(149, 140, 105, 33), width=2)
        d.line(pts, fill=(31, 35, 29, 68), width=1)
        if i % 3 == 0:
            px, py = pts[len(pts)//2]
            d.line((px, py, px+float(RNG.uniform(-8,8)), py+float(RNG.uniform(-8,8))), fill=(34,37,29,55))
    # Sparse desiccated grass is a grounded decal, not a repeated tile symbol.
    for i in range(1200):
        x, y = int(RNG.integers(w)), int(RNG.integers(h))
        if abs(y-1024) < 55:
            continue
        for j in range(int(RNG.integers(2, 6))):
            dx, dy = int(RNG.integers(-5, 6)), int(RNG.integers(-7, 1))
            d.line((x, y, x+dx, y+dy), fill=(126,119,78, int(RNG.integers(60,130))), width=1)
    # Concrete joins, fractured markings, and faint paired tire scars.
    for x in range(0, w, 96):
        top = 991 + int(RNG.integers(-2, 3))
        d.line((x,top,x+int(RNG.integers(-6,7)),1056), fill=(25,30,27,135), width=1)
        d.line((x+2,top,x+3,1054), fill=(143,142,116,55), width=1)
        if x % 288 != 0:
            d.line((x+6,1024,x+24,1024), fill=(172,157,97,125), width=2)
            d.line((x+12,1024,x+15,1024), fill=(68,70,59,200), width=2)
    for y in [1006,1011,1036,1041]:
        for x in range(0,w,24):
            if RNG.random() < .83:
                d.line((x,y,x+int(RNG.integers(12,27)),y+int(RNG.integers(-1,2))),fill=(28,33,29,int(RNG.integers(20,55))),width=2)
    # Small flattened metal scraps and shattered paving; intentionally nonblocking.
    for i in range(100):
        x, y = int(RNG.integers(50,w-50)), int(RNG.integers(50,h-50))
        if abs(y-1024)<42:
            continue
        rw, rh = int(RNG.integers(5,14)), int(RNG.integers(3,9))
        poly = [(x-rw,y),(x-rw+2,y-rh),(x+rw-3,y-rh-2),(x+rw,y+rh),(x-2,y+rh+1)]
        d.polygon([(a+2,b+2) for a,b in poly],fill=(19,25,24,85))
        d.polygon(poly,fill=(82,79,62,180))
        d.line(poly[:3],fill=(143,133,103,160),width=1)
        d.line((x-rw+3,y-1,x+rw-4,y),fill=(43,46,39,150),width=1)
    im.alpha_composite(decals)
    im.convert('RGB').save(OUT/'wasteland.png',optimize=True)


def polygon_material(im, points, base, seed=0, strata=False):
    rng = np.random.default_rng(seed)
    w,h=im.size
    n=noise(w,h,12,rng)
    f=noise(w,h,3,rng)
    yy,xx=np.mgrid[:h,:w]
    tone=(n-.5)*25+(f-.5)*12+rng.normal(0,2,(h,w))
    if strata:
        band=np.sin((yy+noise(w,h,40,rng)*5)*1.3)*3
        band+=np.sin((yy+noise(w,h,35,rng)*8)*.38)*5
        tone+=band
    rgba=np.empty((h,w,4),dtype='uint8')
    for i,v in enumerate(base):
        rgba[:,:,i]=np.clip(v+tone,0,255)
    rgba[:,:,3]=255
    surface=Image.fromarray(rgba)
    mask=Image.new('L',(w,h))
    ImageDraw.Draw(mask).polygon(points,fill=255)
    im.alpha_composite(Image.composite(surface,Image.new('RGBA',(w,h)),mask))


def cliff(w,h,seed):
    rng=np.random.default_rng(seed)
    iw,ih=w+h+64,(w+h)//2+112
    anchor=(iw//2,ih-24-(w+h)//4)
    def proj(x,y):return (anchor[0]+x-y,anchor[1]+(x+y)*.5)
    base=[proj(-w/2,-h/2),proj(w/2,-h/2),proj(w/2,h/2),proj(-w/2,h/2)]
    height=43
    # Segmented chipped top silhouette; all ground corners retain their existing footprint.
    top=[]
    sides=[]
    for side in range(4):
        a,b=base[side],base[(side+1)%4]
        count=max(4,int(math.dist(a,b)//26))
        path=[]
        for j in range(count):
            t=j/count
            jitter=float(rng.uniform(-6,6)) if j else 0
            p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t-height+jitter)
            path.append(p)
        sides.append(path)
        top+=path
    im=Image.new('RGBA',(iw,ih))
    shadow=Image.new('RGBA',im.size)
    sd=ImageDraw.Draw(shadow)
    sd.polygon([(x+8,y+8) for x,y in base],fill=(9,14,12,95))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(4)))
    right=sides[1]+[sides[2][0],base[2],base[1]]
    left=sides[2]+[sides[3][0],base[3],base[2]]
    polygon_material(im,right,(64,67,55),seed+1,True)
    polygon_material(im,left,(83,84,66),seed+2,True)
    polygon_material(im,top,(122,119,94),seed+3)
    overlays=Image.new('RGBA',im.size)
    d=ImageDraw.Draw(overlays,'RGBA')
    # Broad irregular facets break up the front walls into actual rock, not brickwork.
    for side in [1,2]:
        a,b=base[side],base[(side+1)%4]
        count=max(7,int(math.dist(a,b)//25))
        for j in range(count):
            t0=j/count;t1=(j+1)/count
            x0,y0=a[0]+(b[0]-a[0])*t0,a[1]+(b[1]-a[1])*t0
            x1,y1=a[0]+(b[0]-a[0])*t1,a[1]+(b[1]-a[1])*t1
            cut=float(rng.uniform(3,10))
            face=[(x0,y0-3),(x0+float(rng.uniform(-3,3)),y0-height+6),(x1,y1-height+4),(x1-cut*.3,y1-7)]
            val=int(rng.integers(67,94)) if side==2 else int(rng.integers(51,77))
            d.polygon(face,fill=(val+3,val+3,val-10,150))
            d.line(face[1:3],fill=(153,145,111,115),width=1)
            d.line((face[1],face[0]),fill=(24,31,24,90),width=1)
    d.line(top+[top[0]],fill=(169,161,126,140),width=1)
    # Horizontal mineral layers follow both front faces with irregular seams.
    for side in [1,2]:
        a,b=base[side],base[(side+1)%4]
        for layer in [12,26,35]:
            pts=[]
            for j in range(15):
                t=j/14
                pts.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t-layer+float(rng.uniform(-2,2))))
            for segment in range(0,len(pts)-2,3):
                d.line(pts[segment:segment+2],fill=(29,36,27,80),width=1)
            d.line([(x,y-1) for x,y in pts],fill=(144,135,102,30),width=1)
        for j in range(12):
            t=float(rng.random())
            x,y=a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t
            end=int(rng.integers(12,37))
            d.line((x,y-4,x-2,y-end,x+2,y-end-5),fill=(23,30,23,105),width=1)
    im.alpha_composite(overlays)
    # Pitted crags on the top face, clipped to its actual irregular silhouette.
    detail=Image.new('RGBA',im.size)
    dd=ImageDraw.Draw(detail,'RGBA')
    for i in range(int(w*h/180)):
        x=float(rng.uniform(-w/2+5,w/2-5));y=float(rng.uniform(-h/2+5,h/2-5))
        px,py=proj(x,y);py-=height
        r=int(rng.integers(1,5))
        dd.ellipse((px-r,py,px+r+1,py+r),fill=(45,49,35,int(rng.integers(40,100))))
        dd.line((px-r,py,px,py-1),fill=(183,172,133,int(rng.integers(50,130))),width=1)
    for i in range(65):
        x=float(rng.uniform(-w*.44,w*.44));y=float(rng.uniform(-h*.44,h*.44))
        px,py=proj(x,y);py-=height
        r=float(rng.uniform(4,10));v=int(rng.integers(89,139))
        poly=[(px-r,py),(px-r*.4,py-r*.45),(px+r*.5,py-r*.3),(px+r,py+r*.2),(px,py+r*.6)]
        dd.polygon(poly,fill=(v+4,v+1,v-18,170))
        dd.line(poly[:3],fill=(178,164,122,130),width=1)
        dd.line(poly[3:]+poly[:1],fill=(43,49,34,80),width=1)
    # Larger fault lines form connected irregular fractures rather than a repeated rock grid.
    for i in range(18):
        x=float(rng.uniform(-w*.4,w*.4));y=float(rng.uniform(-h*.4,h*.4))
        pts=[]
        for j in range(int(rng.integers(3,7))):
            px,py=proj(x,y);pts.append((px,py-height))
            x+=float(rng.uniform(-10,12));y+=float(rng.uniform(3,12))
        dd.line(pts,fill=(34,42,29,130),width=1)
        dd.line([(a+1,b) for a,b in pts],fill=(184,173,128,80),width=1)
    mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(top,fill=255)
    detail.putalpha(Image.fromarray((np.asarray(detail.getchannel('A'),dtype=float)*np.asarray(mask)/255).astype('uint8')))
    im.alpha_composite(detail)
    im.save(OUT/f'cliff_{w}x{h}.png',optimize=True)
    return anchor


def well():
    w,h=128,112
    yy,xx=np.mgrid[:h,:w]
    x,y=xx-64,yy-64
    radius=np.sqrt((x/54)**2+(y/27)**2)
    im=Image.new('RGBA',(w,h))
    rgba=np.zeros((h,w,4),dtype='uint8')
    rgba[:,:,0]=100;rgba[:,:,1]=86;rgba[:,:,2]=165
    rgba[:,:,3]=np.clip(np.exp(-radius**2*2.1)*30,0,30).astype('uint8')
    im.alpha_composite(Image.fromarray(rgba))
    shadow=Image.new('RGBA',im.size);d=ImageDraw.Draw(shadow)
    d.ellipse((24,49,110,91),fill=(7,12,17,90))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(3)))
    d=ImageDraw.Draw(im,'RGBA')
    d.ellipse((22,45,106,87),fill=(49,50,51,255),outline=(93,88,81,255),width=2)
    d.ellipse((22,41,106,81),fill=(107,102,91,255),outline=(144,137,114,255),width=1)
    d.ellipse((30,45,98,77),fill=(36,38,53,255),outline=(74,72,89,255),width=2)
    # Worn segmented stone rim and muted copper restraining bands.
    for i in range(12):
        a=math.tau*i/12
        x1,y1=64+34*math.cos(a),61+16*math.sin(a)
        x2,y2=64+42*math.cos(a),61+20*math.sin(a)
        d.line((x1,y1,x2,y2),fill=(39,43,42,210),width=2)
        if i%3==0:
            d.line((x1+1,y1,x2+1,y2),fill=(133,126,101,230),width=2)
            d.ellipse((x2-1,y2-1,x2+1,y2+1),fill=(169,161,125,255))
    # Noise texture restricted to the rim keeps material detail subordinate to the glow.
    for i in range(1100):
        px,py=int(RNG.integers(22,107)),int(RNG.integers(41,82))
        rr=((px-64)/42)**2+((py-61)/20)**2
        if .65<rr<1:
            d.point((px,py),fill=(int(RNG.integers(40,150)),int(RNG.integers(45,146)),int(RNG.integers(43,123)),120))
    for r in range(15,0,-1):
        t=1-r/15
        col=(int(74+t*65),int(88+t*97),int(146+t*64),255)
        d.ellipse((64-r*1.85,61-r*.82,64+r*1.85,61+r*.82),fill=col)
    for i in range(5):
        a=i*2.4
        px,py=64+math.cos(a)*18,61+math.sin(a)*7
        d.line((px-5,py,px,py-2,px+4,py),fill=(165,201,230,150),width=1)
    d.line((34,62,46,56),fill=(130,152,192,180),width=1)
    im.save(OUT/'spiritual_well.png',optimize=True)


def essence():
    cell=(96,80);atlas=Image.new('RGBA',(cell[0]*4,cell[1]*2))
    for stage in range(8):
        im=Image.new('RGBA',cell)
        yy,xx=np.mgrid[:cell[1],:cell[0]]
        rr=((xx-48)/30)**2+((yy-50)/14)**2
        rgba=np.zeros((cell[1],cell[0],4),dtype='uint8')
        rgba[:,:,:3]=[111,91,166]
        rgba[:,:,3]=np.clip(np.exp(-rr*2)*(10+stage*1.8),0,28).astype('uint8')
        im.alpha_composite(Image.fromarray(rgba));d=ImageDraw.Draw(im,'RGBA')
        for i in range(8):
            a=i*2.4
            px,py=48+math.cos(a)*16,50+math.sin(a)*7
            d.line((48,50,px,py),fill=(90,102,119,90),width=1)
        if stage==0:
            d.ellipse((45,48,51,51),fill=(108,106,137,110))
        else:
            fullness=stage/7
            crystals=[]
            for i in range(7):
                a=i*2.4;r=6+(i%3)*5
                wx,wy=math.cos(a)*r,math.sin(a)*r
                px,py=48+wx-wy,50+(wx+wy)*.5
                crystals.append((py,i,px))
            for py,i,px in sorted(crystals):
                height=(10+(i%4)*3)*(.35+fullness*.65)
                # Dark grounded bases, cool facets, chipped light tips.
                col=(112,151,167) if i%2==0 else (150,128,177)
                d.ellipse((px-5,py,px+6,py+4),fill=(22,29,38,90))
                d.polygon([(px-4,py+2),(px-3,py-height+4),(px,py-height),(px+4,py-height+5),(px+5,py+1),(px,py+4)],fill=col)
                d.polygon([(px,py-height),(px+4,py-height+5),(px+2,py+2),(px,py+4)],fill=(col[0]+23,col[1]+28,min(255,col[2]+30)))
                d.polygon([(px-3,py-height+4),(px,py-height),(px,py+4),(px-4,py+2)],fill=(max(0,col[0]-30),max(0,col[1]-23),col[2]-15))
                d.line((px,py-height+1,px+1,py+1),fill=(194,214,221,220),width=1)
                d.line((px-2,py-height+7,px+2,py-height+5),fill=(224,229,235,170),width=1)
        atlas.alpha_composite(im,((stage%4)*cell[0],(stage//4)*cell[1]))
    atlas.save(OUT/'essence_growth.png',optimize=True)

if __name__=='__main__':
    ground()
    anchors={}
    for w,h,seed in [(256,384,35001),(256,224,35002)]:
        anchors[f'{w}x{h}']=cliff(w,h,seed)
    well();essence()
    print('Generated original terrain and prop artwork; cliff anchors:',anchors)
