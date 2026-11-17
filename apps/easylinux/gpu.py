"""Grafikkarten messen: Gesamtauslastung, Speicher, Temperatur und Auslastung je Prozess.

NVIDIA (proprietärer Treiber) über nvidia-smi, Intel/AMD über die DRM-Zähler in /proc/<pid>/fdinfo
(die gleiche Quelle wie nvtop/intel_gpu_top). Gemessen wird in einem eigenen Thread, damit die
Oberfläche nie auf nvidia-smi wartet.
"""
import glob
import os
import re
import subprocess
import threading
import time


def _read(path, default=""):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return default


def _pci_name(slot):
    try:
        out = subprocess.run(["lspci", "-mm", "-s", slot], capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.SubprocessError):
        return ""
    parts = re.findall(r'"([^"]*)"', out)
    if len(parts) >= 3:
        vendor = parts[1].replace("Corporation", "").replace("Advanced Micro Devices, Inc.", "AMD").strip()
        dev = parts[2]
        m = re.search(r"\[(.+)\]", dev)  # „GP104 [GeForce GTX 1080]“ → „GeForce GTX 1080“
        return f"{vendor} {m.group(1) if m else dev}".strip()
    return ""


class Card:
    def __init__(self, slot, driver):
        self.slot, self.driver = slot, driver
        self.name = _pci_name(slot) or driver
        self.busy = None           # 0–100 oder None (unbekannt)
        self.mem_used = self.mem_total = 0
        self.temp = None
        self.clock = None          # MHz
        self.driver_version = ""
        self.shared_used = 0       # Bytes im Arbeitsspeicher (integrierte Grafik)


def _cards():
    cards = []
    for c in sorted(glob.glob("/sys/class/drm/card[0-9]*")):
        if "-" in os.path.basename(c):
            continue
        dev = os.path.realpath(f"{c}/device")
        driver = os.path.basename(os.path.realpath(f"{c}/device/driver"))
        if driver and os.path.exists(f"{c}/device/driver"):
            cards.append((os.path.basename(dev), driver, c))
    return cards


class GpuMonitor:
    """Läuft im Hintergrund, solange start() aktiv ist. Werte über cards() und per_pid()."""

    def __init__(self, interval=1.5):
        self.interval = interval
        self._cards = {slot: Card(slot, drv) for slot, drv, _ in _cards()}
        self._sysfs = {slot: path for slot, _, path in _cards()}
        self._pid_busy = {}        # pid → % (höchster Wert über alle Karten)
        self._last_fd = {}         # (pdev, client-id) → (zeit, {engine: ns})
        self._stop = threading.Event()
        self._thread = None
        self._lock = threading.Lock()
        self._has_smi = any(c.driver == "nvidia" for c in self._cards.values()) and \
            os.path.exists("/usr/bin/nvidia-smi")

    # ------------------------------------------------------------ Steuerung
    def start(self):
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()

    def cards(self):
        with self._lock:
            return list(self._cards.values())

    def per_pid(self):
        with self._lock:
            return dict(self._pid_busy)

    def _run(self):
        while not self._stop.is_set():
            try:
                self._sample()
            except Exception:  # Messfehler dürfen den Taskmanager nie beenden
                pass
            self._stop.wait(self.interval)

    def _sample(self):
        pid_busy = {}
        self._sample_fdinfo(pid_busy)
        if self._has_smi:
            self._sample_nvidia(pid_busy)
        self._sample_amd_sysfs()
        with self._lock:
            self._pid_busy = pid_busy

    # ------------------------------------------------------------ Intel/AMD (DRM-fdinfo)
    def _sample_fdinfo(self, pid_busy):
        now = time.monotonic()
        seen, totals = {}, {}
        for pid in os.listdir("/proc"):
            if not pid.isdigit():
                continue
            fd_dir = f"/proc/{pid}/fd"
            try:
                fds = os.listdir(fd_dir)
            except OSError:
                continue
            for fd in fds:
                try:
                    target = os.readlink(f"{fd_dir}/{fd}")
                except OSError:
                    continue
                if not target.startswith("/dev/dri/"):
                    continue
                info = _read(f"/proc/{pid}/fdinfo/{fd}")
                pdev = client = None
                engines = {}
                for line in info.splitlines():
                    k, _, v = line.partition(":")
                    v = v.strip()
                    if k == "drm-pdev":
                        pdev = v
                    elif k == "drm-client-id":
                        client = v
                    elif k.startswith("drm-engine-") and v.endswith(" ns"):
                        engines[k[11:]] = int(v.split()[0])
                if not pdev or client is None or not engines:
                    continue
                key = (pdev, client)
                if key in seen:
                    continue  # derselbe Client über mehrere Dateideskriptoren
                seen[key] = (now, engines)
                last = self._last_fd.get(key)
                if not last or now <= last[0]:
                    continue
                dt = (now - last[0]) * 1e9
                busy = 0.0
                for eng, ns in engines.items():
                    d = max(0, ns - last[1].get(eng, ns)) / dt * 100
                    totals.setdefault(pdev, {}).setdefault(eng, 0.0)
                    totals[pdev][eng] += d
                    busy = max(busy, d)
                pid_busy[int(pid)] = max(pid_busy.get(int(pid), 0.0), min(100.0, busy))
        self._last_fd = seen
        with self._lock:
            for slot, card in self._cards.items():
                if card.driver == "nvidia":
                    continue
                if slot in totals:
                    # Wie Windows: Auslastung des am stärksten belasteten Moduls (3D, Video, Kopieren …)
                    card.busy = min(100.0, max(totals[slot].values()))
                elif card.driver in ("i915", "xe", "amdgpu"):
                    card.busy = 0.0

    # ------------------------------------------------------------ AMD (sysfs)
    def _sample_amd_sysfs(self):
        with self._lock:
            for slot, card in self._cards.items():
                base = f"{self._sysfs[slot]}/device"
                busy = _read(f"{base}/gpu_busy_percent").strip()
                if busy.isdigit():
                    card.busy = float(busy)
                used = _read(f"{base}/mem_info_vram_used").strip()
                total = _read(f"{base}/mem_info_vram_total").strip()
                if used.isdigit() and total.isdigit():
                    card.mem_used, card.mem_total = int(used), int(total)
                for t in glob.glob(f"{base}/hwmon/hwmon*/temp1_input"):
                    v = _read(t).strip()
                    if v.isdigit():
                        card.temp = int(v) // 1000

    # ------------------------------------------------------------ NVIDIA
    def _sample_nvidia(self, pid_busy):
        try:
            out = subprocess.run(
                ["nvidia-smi", "--query-gpu=pci.bus_id,utilization.gpu,memory.used,memory.total,"
                 "temperature.gpu,clocks.gr,driver_version", "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=3).stdout
            pmon = subprocess.run(["nvidia-smi", "pmon", "-c", "1", "-s", "u"],
                                  capture_output=True, text=True, timeout=3).stdout
        except (OSError, subprocess.SubprocessError):
            return
        with self._lock:
            for line in out.splitlines():
                f = [x.strip() for x in line.split(",")]
                if len(f) < 7:
                    continue
                # „00000000:01:00.0“ → „0000:01:00.0“
                slot = f[0].lower()[-12:]
                card = self._cards.get(slot)
                if not card:
                    continue
                num = lambda s: float(s) if re.fullmatch(r"[\d.]+", s) else None  # noqa: E731
                card.busy = num(f[1])
                card.mem_used = int((num(f[2]) or 0) * 1024 * 1024)
                card.mem_total = int((num(f[3]) or 0) * 1024 * 1024)
                t = num(f[4])
                card.temp = int(t) if t is not None else None
                c = num(f[5])
                card.clock = int(c) if c is not None else None
                card.driver_version = f[6]
        for line in pmon.splitlines():
            f = line.split()
            if line.startswith("#") or len(f) < 4 or not f[1].isdigit():
                continue
            pct = max([float(x) for x in f[3:6] if re.fullmatch(r"[\d.]+", x)] or [0.0])
            pid = int(f[1])
            pid_busy[pid] = max(pid_busy.get(pid, 0.0), pct)


if __name__ == "__main__":
    m = GpuMonitor(interval=1)
    m.start()
    time.sleep(3.5)
    for c in m.cards():
        print(c.slot, c.driver, c.name, c.busy, c.mem_used, c.mem_total, c.temp, c.clock, c.driver_version)
    top = sorted(m.per_pid().items(), key=lambda kv: -kv[1])[:5]
    print("pro Prozess:", top)
    assert m.cards(), "keine Grafikkarte gefunden"
