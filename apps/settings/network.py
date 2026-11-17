"""Seite „Netzwerk & Internet“ wie bei Windows 11: Verbindungsstatus, WLAN mit Netzwerkliste, Ethernet,
VPN und Flugzeugmodus. Alles über nmcli (NetworkManager), ohne Administratorrechte.

Passwörter fragt nicht diese Seite ab: Braucht ein WLAN eines, fragt NetworkManager den Passwort-Dialog
von Plasma (plasma-nm) – das Passwort läuft so nie über Befehlszeilen oder diese App.
"""
import os
import re
import subprocess
import threading

from PySide6.QtCore import QObject, QTimer, Property, Signal, Slot

ENV = dict(os.environ, LANG="C", LC_ALL="C")


def nmcli(*args, timeout=15):
    try:
        r = subprocess.run(["nmcli", *args], capture_output=True, text=True, timeout=timeout, env=ENV)
        return r.returncode, r.stdout, r.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, "", str(exc)


def split_terse(line):
    """nmcli -t trennt mit „:“ und maskiert „:“ in Werten als „\\:“."""
    return [f.replace("\\:", ":").replace("\\\\", "\\") for f in re.split(r"(?<!\\):", line)]


def bars(signal):
    return "network-wireless-signal-" + ("excellent" if signal >= 75 else "good" if signal >= 50
                                        else "ok" if signal >= 25 else "weak")


def device_details(dev):
    _, out, _ = nmcli("-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR", "dev", "show", dev)
    info = {}
    for line in out.splitlines():
        k, _, v = line.partition(":")
        k = k.split("[")[0]
        v = v.replace("\\:", ":")
        if v and k not in info:
            info[k] = v
    speed = ""
    try:
        with open(f"/sys/class/net/{dev}/speed") as fh:
            s = fh.read().strip()
            if s.isdigit() and int(s) > 0:
                speed = f"{s} Mbit/s"
    except OSError:
        pass
    rows = [("IPv4-Adresse", info.get("IP4.ADDRESS", "–").split("/")[0]),
            ("Standardgateway", info.get("IP4.GATEWAY", "–")),
            ("DNS-Server", info.get("IP4.DNS", "–")),
            ("IPv6-Adresse", info.get("IP6.ADDRESS", "–").split("/")[0]),
            ("Physische Adresse (MAC)", info.get("GENERAL.HWADDR", "–"))]
    if speed:
        rows.append(("Verbindungsgeschwindigkeit", speed))
    return [{"label": k, "value": v} for k, v in rows]


class Network(QObject):
    changed = Signal()
    wifiChanged = Signal()
    message = Signal(str, bool)

    def __init__(self):
        super().__init__()
        self._devices, self._wifi, self._vpns = [], [], []
        self._wifi_on = False
        self._airplane = False
        self._scanning = False
        self._busy = ""

    # ------------------------------------------------------------ Lesen
    @Slot()
    def refresh(self):
        threading.Thread(target=self._load, daemon=True).start()

    def _load(self):
        _, radio, _ = nmcli("-t", "-f", "WIFI", "radio")
        wifi_on = radio.strip() == "enabled"
        devices = []
        _, out, _ = nmcli("-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev")
        for line in out.splitlines():
            f = split_terse(line)
            if len(f) < 4 or f[1] not in ("ethernet", "wifi"):
                continue
            connected = f[2].startswith("connected") and "externally" not in f[2]
            devices.append({"device": f[0], "type": f[1], "connected": connected,
                            "state": f[2], "connection": f[3],
                            "details": device_details(f[0]) if connected else []})
        vpns = []
        _, out, _ = nmcli("-t", "-f", "NAME,TYPE,ACTIVE,UUID", "con", "show")
        for line in out.splitlines():
            f = split_terse(line)
            if len(f) >= 4 and f[1] in ("vpn", "wireguard"):
                vpns.append({"name": f[0], "active": f[2] == "yes", "uuid": f[3]})
        airplane = self._airplane_state()
        QTimer.singleShot(0, self, lambda: self._loaded(devices, vpns, wifi_on, airplane))
        if wifi_on:
            self._load_wifi(False)

    def _loaded(self, devices, vpns, wifi_on, airplane):
        self._devices, self._vpns, self._wifi_on, self._airplane = devices, vpns, wifi_on, airplane
        self.changed.emit()

    def _load_wifi(self, rescan):
        _, saved, _ = nmcli("-t", "-f", "NAME,TYPE", "con", "show")
        known = {split_terse(l)[0] for l in saved.splitlines() if l.endswith(":802-11-wireless")}
        _, out, _ = nmcli("-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list",
                          "--rescan", "yes" if rescan else "auto", timeout=30)
        nets = {}
        for line in out.splitlines():
            f = split_terse(line)
            if len(f) < 4 or not f[1]:
                continue  # versteckte Netze ohne Namen
            ssid, signal = f[1], int(f[2] or 0)
            cur = nets.get(ssid)
            if cur and cur["signal"] >= signal and not f[0] == "*":
                continue
            nets[ssid] = {"ssid": ssid, "signal": signal, "icon": bars(signal),
                          "secure": f[3] not in ("", "--"), "security": f[3] if f[3] != "--" else "Offen",
                          "active": f[0] == "*" or (cur or {}).get("active", False), "known": ssid in known}
        wifi = sorted(nets.values(), key=lambda n: (not n["active"], -n["signal"]))
        QTimer.singleShot(0, self, lambda: self._wifi_loaded(wifi))

    def _wifi_loaded(self, wifi):
        self._wifi, self._scanning = wifi, False
        self.wifiChanged.emit()

    @staticmethod
    def _airplane_state():
        try:
            out = subprocess.run(["rfkill", "-n", "-o", "SOFT"], capture_output=True, text=True, timeout=5,
                                 env=ENV).stdout.split()
        except (OSError, subprocess.TimeoutExpired):
            return False
        return bool(out) and all(s == "blocked" for s in out)

    @Property("QVariantList", notify=changed)
    def devices(self):
        return self._devices

    @Property("QVariantMap", notify=changed)
    def status(self):
        """Kopfzeile wie bei Windows: womit ist der Computer gerade online?"""
        con = [d for d in self._devices if d["connected"]]
        if self._airplane:
            return {"title": "Flugzeugmodus", "subtitle": "Alle Funkverbindungen sind aus", "icon": "network-flightmode-on",
                    "online": False}
        if not con:
            return {"title": "Nicht verbunden", "subtitle": "Kein Kabel und kein WLAN verbunden",
                    "icon": "network-disconnect", "online": False}
        d = con[0]
        kind = "Ethernet" if d["type"] == "ethernet" else "WLAN"
        return {"title": d["connection"] if d["type"] == "wifi" else "Ethernet",
                "subtitle": f"Verbunden · {kind}" if d["type"] == "wifi" else "Verbunden",
                "icon": "network-wired-activated" if d["type"] == "ethernet" else "network-wireless-connected-100",
                "online": True}

    @Property("QVariantList", notify=wifiChanged)
    def wifiNetworks(self):
        return self._wifi

    @Property("QVariantList", notify=changed)
    def vpns(self):
        return self._vpns

    @Property(bool, notify=changed)
    def wifiEnabled(self):
        return self._wifi_on

    @Property(bool, notify=changed)
    def hasWifi(self):
        return any(d["type"] == "wifi" for d in self._devices)

    @Property(bool, notify=changed)
    def airplane(self):
        return self._airplane

    @Property(bool, notify=wifiChanged)
    def scanning(self):
        return self._scanning

    @Property(str, notify=changed)
    def busy(self):
        return self._busy

    # ------------------------------------------------------------ Ändern
    def _run(self, args, ok_text, busy="", timeout=60, after=None):
        self._busy = busy
        self.changed.emit()

        def work():
            code, _, err = nmcli(*args, timeout=timeout)
            QTimer.singleShot(0, self, lambda: self._ran(code, err, ok_text, after))
        threading.Thread(target=work, daemon=True).start()

    def _ran(self, code, err, ok_text, after):
        self._busy = ""
        if code == 0:
            if ok_text:
                self.message.emit(ok_text, True)
        elif "Secrets were required" in err or "secrets" in err.lower():
            self.message.emit("Kein oder falsches Passwort – die Verbindung wurde nicht hergestellt.", False)
        elif "not authorized" in err.lower():
            self.message.emit("Dafür fehlen die Berechtigungen.", False)
        else:
            self.message.emit(f"Das hat nicht geklappt: {err[:160] or 'unbekannter Fehler'}", False)
        if after:
            after()
        self.refresh()

    @Slot(bool)
    def setWifiEnabled(self, on):
        self._run(["radio", "wifi", "on" if on else "off"], "")

    @Slot()
    def scan(self):
        self._scanning = True
        self.wifiChanged.emit()
        threading.Thread(target=self._load_wifi, args=(True,), daemon=True).start()

    @Slot(str)
    def connectWifi(self, ssid):
        net = next((n for n in self._wifi if n["ssid"] == ssid), None)
        if net and net["known"]:
            self._run(["con", "up", "id", ssid], f"Mit „{ssid}“ verbunden.", busy=ssid)
        else:
            # Ohne --ask: NetworkManager fragt das Passwort über den Plasma-Dialog ab
            self._run(["dev", "wifi", "connect", ssid], f"Mit „{ssid}“ verbunden.", busy=ssid, timeout=120)

    @Slot(str)
    def disconnectWifi(self, ssid):
        self._run(["con", "down", "id", ssid], f"Verbindung mit „{ssid}“ getrennt.")

    @Slot(str)
    def forgetWifi(self, ssid):
        self._run(["con", "delete", "id", ssid], f"„{ssid}“ wurde vergessen.")

    @Slot(str, bool)
    def setVpn(self, uuid, on):
        name = next((v["name"] for v in self._vpns if v["uuid"] == uuid), "VPN")
        self._run(["con", "up" if on else "down", "uuid", uuid],
                  f"„{name}“ {'verbunden' if on else 'getrennt'}.", busy=uuid)

    @Slot(bool)
    def setAirplane(self, on):
        # rfkill sperrt WLAN, Bluetooth und Mobilfunk gemeinsam – wie der Flugzeugmodus bei Windows
        try:
            subprocess.run(["rfkill", "block" if on else "unblock", "all"], capture_output=True, timeout=10)
        except (OSError, subprocess.TimeoutExpired):
            self.message.emit("Der Flugzeugmodus ließ sich nicht umschalten.", False)
        self.refresh()


if __name__ == "__main__":
    assert split_terse(r"*:Netz\:A:44:WPA2") == ["*", "Netz:A", "44", "WPA2"]
    n = Network()
    n._load()
    import time
    time.sleep(0.5)
    print(n._devices, n._vpns, n._wifi_on, n._wifi[:3])
