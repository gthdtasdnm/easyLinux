# VM-Werkzeuge (nur für die Entwicklung)

Steuern die Test-VM (GNOME Boxes / libvirt-Session, Standard-Name `boxes-unknown-2`) vom Host aus.

| Befehl | Zweck |
|---|---|
| `vssh <befehl>` | SSH in die VM (Host-Port 2222 → VM:22, Benutzer `test`) |
| `vsess <befehl>` | wie `vssh`, aber mit Umgebung der grafischen Sitzung (D-Bus, Wayland) – z. B. für `./install.sh` |
| `vm shot` | Bildschirmfoto der VM (Pfad wird ausgegeben) |
| `vm key KEY_…` / `vm type TEXT` | Tastatur über `virsh send-key` (`VMKB=de` oder `us`) |
| `vm mouse-start`, `vm click X Y`, `vm dbl X Y` | Maus über ein uinput-Gerät im Gast (QEMU-Mausereignisse kommen im Gast nicht an) |

Snapshots: `virsh -c qemu:///session snapshot-revert boxes-unknown-2 frisch-aus`

## So wurde die VM eingerichtet
- Boxes erkannte CachyOS nicht und wählte rtl8139 + IDE (Netz ~100 B/s). Umgestellt auf virtio-blk und
  virtio-net per `<qemu:commandline>` mit `hostfwd=tcp:127.0.0.1:2222-:22` (NIC auf PCI-Slot 0x10).
- Im installierten System zusätzlich: `sshd` aktiviert, UFW-Regel „22/tcp von 10.0.2.2 erlauben“. Sonst unverändert.
- Testbenutzer `test` / Passwort `testpass1234` (nur VM).
