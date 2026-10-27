# Virtuelle Absolut-Maus über /dev/uinput. Liest Befehle aus einer FIFO:
#   move X Y | click X Y [left|right] | dbl X Y   (X/Y in Bildschirmpixeln)
import os, fcntl, struct, time, sys
W, H = int(sys.argv[1]), int(sys.argv[2]); FIFO = '/tmp/vmouse'
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
BTN = {'left': 0x110, 'right': 0x111}
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT = 0x40045564, 0x40045565, 0x40045567
UI_DEV_CREATE = 0x5501
fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
for ev in (EV_SYN, EV_KEY, EV_ABS): fcntl.ioctl(fd, UI_SET_EVBIT, ev)
for b in BTN.values(): fcntl.ioctl(fd, UI_SET_KEYBIT, b)
for a in (0, 1): fcntl.ioctl(fd, UI_SET_ABSBIT, a)
absmax = [0]*64; absmax[0] = W - 1; absmax[1] = H - 1
dev = struct.pack('80sHHHHi', b'easylinux-pointer', 3, 1, 1, 1, 0)
dev += struct.pack('64i', *absmax) + struct.pack('64i', *([0]*64)) * 3
os.write(fd, dev); fcntl.ioctl(fd, UI_DEV_CREATE)
def emit(t, c, v): os.write(fd, struct.pack('llHHi', 0, 0, t, c, v))
def syn(): emit(EV_SYN, 0, 0)
def move(x, y): emit(EV_ABS, 0, x); emit(EV_ABS, 1, y); syn()
def click(b):
    emit(EV_KEY, BTN[b], 1); syn(); time.sleep(0.05); emit(EV_KEY, BTN[b], 0); syn()
import stat
if os.path.exists(FIFO) and not stat.S_ISFIFO(os.stat(FIFO).st_mode): os.remove(FIFO)
if not os.path.exists(FIFO): os.mkfifo(FIFO, 0o666)
os.chmod(FIFO, 0o666)
while True:
    with open(FIFO) as f:
        for line in f:
            p = line.split()
            if not p: continue
            move(int(p[1]), int(p[2])); time.sleep(0.1)
            if p[0] == 'click': click(p[3] if len(p) > 3 else 'left')
            elif p[0] == 'dbl': click('left'); time.sleep(0.08); click('left')
