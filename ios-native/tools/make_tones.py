# Synthesizes Dewby's bundled notification tones (original, no licensing). Run: python3 tools/make_tones.py
import wave,struct,math,random
SR=44100;random.seed(7)
def save(n,s):
  w=wave.open(f'/tmp/{n}.wav','w');w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR)
  m=max(abs(x) for x in s) or 1
  w.writeframes(b''.join(struct.pack('<h',int(x/m*0.8*32767)) for x in s));w.close()
def drop(t0,f0,dur,buf):
  for i in range(int(dur*SR)):
    t=i/SR;f=f0*(1+2.5*t/dur);j=int(t0*SR)+i
    if j<len(buf): buf[j]+=math.sin(2*math.pi*f*t)*math.exp(-t*30)
def noise(dur,env,lp):
  b=[];y=0
  for i in range(int(dur*SR)):
    y+=lp*(random.uniform(-1,1)-y);b.append(y*env(i/SR))
  return b
def drip():
  b=[0.0]*int(1.2*SR);drop(0,700,0.15,b);drop(0.45,850,0.15,b);return b
def splash():
  b=noise(1.0,lambda t:min(t*40,1)*math.exp(-t*5),0.5)
  for k in range(8): drop(0.05+k*0.07+random.random()*0.05,600+random.random()*900,0.1,b)
  return b
def stream():
  b=noise(2.5,lambda t:min(t*4,1)*max(min((2.5-t)*4,1),0)*(0.7+0.3*math.sin(t*9)),0.15)
  for k in range(20): drop(random.random()*2.3,900+random.random()*1200,0.06,b)
  return b
def tones(notes,dur,dec,harm):
  b=[0.0]*int(dur*SR)
  for (st,f) in notes:
    for i in range(int((dur-st)*SR)):
      j=int(st*SR)+i
      if j>=len(b): break
      t=i/SR;b[j]+=sum(a*math.sin(2*math.pi*f*h*t) for h,a in harm)*math.exp(-t*dec)
  return b
save('dewby_drip',drip());save('dewby_splash',splash());save('dewby_stream',stream())
save('dewby_chime',tones([(0,880),(0.25,1318.5)],1.8,3,[(1,1),(2.76,.3)]))
save('dewby_marimba',tones([(0,523.25),(0.15,659.25),(0.3,783.99),(0.45,1046.5)],1.4,9,[(1,1),(4,.25)]))
save('dewby_bells',tones([(0,1046.5),(0.3,1318.5),(0.6,1567.98)],2.4,2.2,[(1,1),(2.4,.4),(5.4,.15)]))
# Convert to CAF (Mac: afconvert -f caff -d LEI16 x.wav x.caf; Linux: ffmpeg -i x.wav -c:a pcm_s16le -f caf x.caf)
import subprocess,shutil
for n in ['dewby_drip','dewby_splash','dewby_stream','dewby_chime','dewby_marimba','dewby_bells']:
  out=f'Dewby/Resources/Sounds/{n}.caf'
  if shutil.which('afconvert'): subprocess.run(['afconvert','-f','caff','-d','LEI16',f'/tmp/{n}.wav',out],check=True)
  else: subprocess.run(['ffmpeg','-loglevel','error','-y','-i',f'/tmp/{n}.wav','-c:a','pcm_s16le','-f','caf',out],check=True)
