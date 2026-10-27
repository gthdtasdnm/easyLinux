"""Messwerte für den Leistung-Tab: Prozessor, Arbeitsspeicher, Laufwerke, Netzwerk, Grafikkarte."""
import glob
import json
import os
import subprocess
import time


def _read(path, default=""):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return default


def human_rate(n):
    """Bytes pro Sekunde → „1,2 MB/s“."""
    for unit in ("B/s", "KB/s", "MB/s", "GB/s"):
        if n < 1024 or unit == "GB/s":
            return f"{n:.0f} {unit}" if unit in ("B/s", "KB/s") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1024


def human_bits(n):
    """Bytes pro Sekunde → „12,3 Mbit/s“ (wie bei Windows für Netzwerk)."""
    n *= 8
    for unit in ("bit/s", "Kbit/s", "Mbit/s", "Gbit/s"):
        if n < 1000 or unit == "Gbit/s":
            return f"{n:.0f} {unit}" if unit in ("bit/s", "Kbit/s") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1000


def human_size(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1024


def uptime_text():
    secs = int(float(_read("/proc/uptime", "0").split()[0]))
    d, rest = divmod(secs, 86400)
    h, rest = divmod(rest, 3600)
    m, s = divmod(rest, 60)
    return f"{d}:{h:02}:{m:02}:{s:02}"


def cpu_model():
    for line in _read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return "Prozessor"


class Device:
    """Ein Eintrag in der linken Liste des Leistung-Tabs."""

    def __init__(self, key, kind, title, color):
        self.key, self.kind, self.title, self.color = key, kind, title, color
        self.subtitle = ""       # kurzer Wert unter dem Titel, z. B. „12 %“
        self.value = 0.0         # 0–100 für das Diagramm
        self.value2 = None       # zweite Linie (z. B. Senden), 0–100
        self.scale_text = "100 %"
        self.details = []        # [(Bezeichnung, Wert)]
        self.history = []
        self.history2 = []

    def push(self):
        self.history = (self.history + [self.value])[-60:]
        if self.value2 is not None:
            self.history2 = (self.history2 + [self.value2])[-60:]

    def as_dict(self):
        return {"key": self.key, "kind": self.kind, "title": self.title, "subtitle": self.subtitle,
                "color": self.color, "value": self.value, "history": self.history,
                "history2": self.history2, "scaleText": self.scale_text,
                "details": [{"label": k, "value": v} for k, v in self.details]}


class Performance:
    def __init__(self):
        self._cpu_last = None
        self._disk_last = {}
        self._net_last = {}
        self._net_peak = {}
        self._t = None
        self.devices = {}
        self._model = cpu_model()
        self._cores = self._count_cores()
        self._addr_cache = (0, {})

    @staticmethod
    def _count_cores():
        cores = {(l1, l2) for l1, l2 in (
            (_read(f"{p}/topology/physical_package_id").strip(), _read(f"{p}/topology/core_id").strip())
            for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*"))}
        return len(cores) or os.cpu_count() or 1

    def _dev(self, key, kind, title, color):
        if key not in self.devices:
            self.devices[key] = Device(key, kind, title, color)
        return self.devices[key]

    # ------------------------------------------------------------ Prozessor
    def _cpu(self, dt):
        dev = self._dev("cpu", "cpu", "Prozessor", "#3daee9")
        vals = [int(x) for x in _read("/proc/stat").splitlines()[0].split()[1:]]
        idle, total = vals[3] + vals[4], sum(vals)
        if self._cpu_last:
            d_total, d_idle = total - self._cpu_last[0], idle - self._cpu_last[1]
            dev.value = 100.0 * (d_total - d_idle) / d_total if d_total else 0.0
        self._cpu_last = (total, idle)
        mhz = [float(l.split(":")[1]) for l in _read("/proc/cpuinfo").splitlines() if l.startswith("cpu MHz")]
        speed = f"{sum(mhz) / len(mhz) / 1000:.2f} GHz".replace(".", ",") if mhz else "–"
        procs = threads = 0
        for d in os.listdir("/proc"):
            if d.isdigit():
                procs += 1
                for line in _read(f"/proc/{d}/status").splitlines():
                    if line.startswith("Threads:"):
                        threads += int(line.split()[1])
                        break
        dev.subtitle = f"{dev.value:.0f} %  {speed}"
        dev.details = [("Auslastung", f"{dev.value:.0f} %"), ("Geschwindigkeit", speed),
                       ("Prozesse", str(procs)), ("Threads", str(threads)),
                       ("Betriebszeit", uptime_text()), ("Modell", self._model),
                       ("Kerne", str(self._cores)), ("Logische Prozessoren", str(os.cpu_count()))]

    # ------------------------------------------------------------ Arbeitsspeicher
    def _memory(self):
        dev = self._dev("memory", "memory", "Arbeitsspeicher", "#9b59b6")
        info = {}
        for line in _read("/proc/meminfo").splitlines():
            k, v = line.split(":", 1)
            info[k] = int(v.split()[0]) * 1024
        total = info.get("MemTotal", 1)
        avail = info.get("MemAvailable", 0)
        used = total - avail
        dev.value = 100.0 * used / total
        swap_total = info.get("SwapTotal", 0)
        swap_used = swap_total - info.get("SwapFree", 0)
        dev.subtitle = f"{human_size(used)}/{human_size(total)} ({dev.value:.0f} %)"
        dev.scale_text = human_size(total)
        dev.details = [("In Verwendung", human_size(used)), ("Verfügbar", human_size(avail)),
                       ("Zwischengespeichert", human_size(info.get("Cached", 0) + info.get("Buffers", 0))),
                       ("Auslagerung", f"{human_size(swap_used)} von {human_size(swap_total)}"),
                       ("Gesamt", human_size(total))]

    # ------------------------------------------------------------ Laufwerke
    def _disks(self, dt):
        present = set()
        stats = {}
        for line in _read("/proc/diskstats").splitlines():
            f = line.split()
            if len(f) >= 14:
                stats[f[2]] = (int(f[5]) * 512, int(f[9]) * 512, int(f[12]))  # gelesen, geschrieben, ms aktiv
        idx = 0
        for name in sorted(os.listdir("/sys/block")):
            if name.startswith(("loop", "ram", "zram", "sr", "dm-", "md")) or name not in stats:
                continue
            size = int(_read(f"/sys/block/{name}/size", "0") or 0) * 512
            if not size:
                continue
            present.add(name)
            rot = _read(f"/sys/block/{name}/queue/rotational").strip() == "1"
            kind = "HDD" if rot else "SSD"
            if name.startswith("vd"):
                kind = "Virtuell"
            removable = _read(f"/sys/block/{name}/removable").strip() == "1"
            if removable:
                kind = "Wechseldatenträger"
            dev = self._dev("disk:" + name, "disk", f"Datenträger {idx} ({name})", "#27ae60")
            idx += 1
            r, w, busy = stats[name]
            last = self._disk_last.get(name)
            rr = wr = 0.0
            if last and dt:
                rr, wr = (r - last[0]) / dt, (w - last[1]) / dt
                dev.value = min(100.0, (busy - last[2]) / (dt * 1000) * 100)
            self._disk_last[name] = (r, w, busy)
            model = (_read(f"/sys/block/{name}/device/model").strip()
                     or _read(f"/sys/block/{name}/device/name").strip() or name)
            dev.subtitle = f"{kind}  {dev.value:.0f} %"
            dev.details = [("Aktive Zeit", f"{dev.value:.0f} %"), ("Lesegeschwindigkeit", human_rate(rr)),
                           ("Schreibgeschwindigkeit", human_rate(wr)), ("Kapazität", human_size(size)),
                           ("Typ", kind), ("Modell", model)]
        return {"disk:" + n for n in present}

    # ------------------------------------------------------------ Netzwerk
    def _addresses(self):
        t, cache = self._addr_cache
        if time.monotonic() - t < 10:
            return cache
        cache = {}
        try:
            out = subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True, timeout=2).stdout
            for link in json.loads(out or "[]"):
                v4 = [a["local"] for a in link.get("addr_info", []) if a.get("family") == "inet"]
                v6 = [a["local"] for a in link.get("addr_info", [])
                      if a.get("family") == "inet6" and a.get("scope") == "global"]
                cache[link["ifname"]] = (v4[0] if v4 else "–", v6[0] if v6 else "–")
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        self._addr_cache = (time.monotonic(), cache)
        return cache

    def _network(self, dt):
        present = set()
        addrs = self._addresses()
        for name in sorted(os.listdir("/sys/class/net")):
            base = f"/sys/class/net/{name}"
            # Nur echte Adapter (mit Gerät), keine virtuellen Brücken/Tunnel
            if name == "lo" or not os.path.exists(f"{base}/device"):
                continue
            present.add(name)
            wifi = os.path.exists(f"{base}/wireless") or os.path.exists(f"{base}/phy80211")
            dev = self._dev("net:" + name, "net", "WLAN" if wifi else "Ethernet", "#e67e22")
            rx = int(_read(f"{base}/statistics/rx_bytes", "0") or 0)
            tx = int(_read(f"{base}/statistics/tx_bytes", "0") or 0)
            last = self._net_last.get(name)
            rr = tr = 0.0
            if last and dt:
                rr, tr = max(0, rx - last[0]) / dt, max(0, tx - last[1]) / dt
            self._net_last[name] = (rx, tx)
            # Skala wie bei Windows: passt sich der höchsten Rate der letzten Minute an
            peak = max([rr, tr] + self._net_peak.get(name, []))
            self._net_peak[name] = (self._net_peak.get(name, []) + [max(rr, tr)])[-60:]
            scale = 128 * 1024
            while scale < peak:
                scale *= 2
            dev.value, dev.value2 = 100.0 * rr / scale, 100.0 * tr / scale
            dev.scale_text = human_bits(scale)
            up = _read(f"{base}/operstate").strip() == "up"
            dev.subtitle = f"E: {human_bits(rr)}  S: {human_bits(tr)}" if up else "Nicht verbunden"
            v4, v6 = addrs.get(name, ("–", "–"))
            speed = _read(f"{base}/speed").strip()
            dev.details = [("Empfangen", human_bits(rr)), ("Senden", human_bits(tr)),
                           ("Adapter", name), ("Verbindungstyp", "WLAN" if wifi else "Ethernet"),
                           ("IPv4-Adresse", v4), ("IPv6-Adresse", v6)]
            if speed.isdigit() and int(speed) > 0:
                dev.details.append(("Verbindungsgeschwindigkeit", f"{int(speed)} Mbit/s"))
        return {"net:" + n for n in present}

    # ------------------------------------------------------------ Grafikkarte
    def _gpus(self):
        present = set()
        for i, card in enumerate(sorted(glob.glob("/sys/class/drm/card[0-9]"))):
            base = f"{card}/device"
            busy = _read(f"{base}/gpu_busy_percent").strip()
            if not busy.isdigit():
                continue  # nur Grafikkarten, die ihre Auslastung melden (AMD)
            key = "gpu:" + os.path.basename(card)
            present.add(key)
            dev = self._dev(key, "gpu", f"GPU {i}", "#e74c3c")
            dev.value = float(busy)
            used = int(_read(f"{base}/mem_info_vram_used", "0") or 0)
            total = int(_read(f"{base}/mem_info_vram_total", "0") or 0)
            dev.subtitle = f"{dev.value:.0f} %"
            dev.details = [("Auslastung", f"{dev.value:.0f} %")]
            if total:
                dev.details.append(("Grafikspeicher", f"{human_size(used)} von {human_size(total)}"))
        return present

    def update(self):
        now = time.monotonic()
        dt = now - self._t if self._t else 0
        self._t = now
        self._cpu(dt)
        self._memory()
        present = {"cpu", "memory"} | self._disks(dt) | self._network(dt) | self._gpus()
        for key in list(self.devices):
            if key not in present:
                del self.devices[key]
        for dev in self.devices.values():
            dev.push()
        order = {"cpu": 0, "memory": 1, "disk": 2, "net": 3, "gpu": 4}
        return [d.as_dict() for d in sorted(self.devices.values(), key=lambda d: (order[d.kind], d.key))]
