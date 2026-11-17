"""Netzwerk-Durchsatz je Prozess (für die Spalte „Netzwerk“ im Taskmanager).

Liest die Byte-Zähler der TCP-Verbindungen über `ss` – ohne Administratorrechte, aber nur für
Verbindungen eigener Prozesse.
shortcut: nur TCP; UDP/QUIC (z. B. YouTube im Browser) zählt nicht mit. Für vollständige Werte
bräuchte es einen root-Dienst mit eBPF/nftables-Zählern je cgroup.
"""
import re
import subprocess
import time

_SOCK = re.compile(r"users:\(\((.*?)\)\)")
_PID = re.compile(r"pid=(\d+)")
_BYTES = re.compile(r"\b(bytes_acked|bytes_received):(\d+)")


def parse(text):
    """ss -tinpH-Ausgabe → {(Verbindung, pid): Bytes gesamt}."""
    result = {}
    current = None
    for line in text.splitlines():
        if not line.startswith(("\t", " ")):
            m = _SOCK.search(line)
            f = line.split()
            conn = " ".join(f[2:4]) if len(f) >= 4 else line
            pids = sorted({int(p) for p in _PID.findall(m.group(1))}) if m else []
            current = (conn, pids[0]) if pids else None
        elif current:
            total = sum(int(v) for _, v in _BYTES.findall(line))
            result[current] = result.get(current, 0) + total
    return result


class NetMonitor:
    def __init__(self):
        self._last = {}
        self._t = None

    def update(self):
        """→ {pid: Bytes pro Sekunde} seit dem letzten Aufruf."""
        try:
            out = subprocess.run(["ss", "-tinpH"], capture_output=True, text=True, timeout=2).stdout
        except (OSError, subprocess.SubprocessError):
            return {}
        now = time.monotonic()
        cur = parse(out)
        rates = {}
        if self._t and now > self._t:
            dt = now - self._t
            for key, total in cur.items():
                prev = self._last.get(key)
                if prev is not None and total >= prev:
                    rates[key[1]] = rates.get(key[1], 0.0) + (total - prev) / dt
        self._last, self._t = cur, now
        return rates


if __name__ == "__main__":
    sample = ("0 0 192.168.0.163:51440 192.168.0.133:22 users:((\"ssh\",pid=4823,fd=3))\n"
              "\t cubic bytes_sent:17546 bytes_acked:17495 bytes_received:11453 segs_out:549\n"
              "0 0 1.2.3.4:1 5.6.7.8:443\n\t cubic bytes_acked:5 bytes_received:7\n")
    p = parse(sample)
    assert p == {("192.168.0.163:51440 192.168.0.133:22", 4823): 17495 + 11453}, p
    m = NetMonitor()
    m.update()
    time.sleep(1)
    print("ok", m.update())
