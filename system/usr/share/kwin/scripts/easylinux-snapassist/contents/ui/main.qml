/*
    Snap Assist für KWin (easyLinux): Wird ein Fenster angedockt, erscheinen in der freien Fläche die
    übrigen Fenster als Vorschau. Ein Klick dockt das gewählte Fenster dort an; Esc, ein Klick daneben
    oder ein Fensterwechsel bricht ab.

    Hälfte angedockt → Auswahl in der anderen Hälfte (oder im freien Viertel, wenn dort schon eins liegt).
    Viertel angedockt → zwei Auswahlen gleichzeitig: im Viertel darüber/darunter und auf der anderen Seite.

    Einstellungen (kwinrc, Gruppe [Script-easylinux-snapassist], gesetzt von den easyLinux-Einstellungen):
      AllScreens    Fenster von allen Bildschirmen anbieten (Standard: ja)
      WhenOccupied  auch anbieten, wenn die freie Fläche schon belegt ist (Standard: nein, wie Windows)
      Quarters      auch beim Andocken in eine Ecke (Standard: ja)
*/
import QtQuick
import org.kde.kwin

Item {
    id: root

    readonly property string pickerTitle: "easyLinux-Andock-Assistent"
    // Während wir selbst andocken, nicht erneut anbieten. Zeitstempel statt Timer: Timer im Hauptteil eines
    // KWin-Skripts feuern nie (kein Fenster) – „busy“ blieb sonst nach der ersten Auswahl für immer gesetzt.
    property double busyUntil: 0
    property var hooks: []         // [Fenster, Funktion] – beim Entladen wieder lösen
    readonly property var pickers: [pickerA, pickerB]

    function setting(key, fallback) {
        const value = KWin.readConfig(key, fallback);
        return value === true || value === "true";
    }

    function hook(window) {
        if (window && window.normalWindow) {
            const fn = () => root.tiled(window);
            window.tileChanged.connect(fn);
            hooks.push([window, fn]);
        }
    }

    function onDesktop(window) {
        if (window.onAllDesktops)
            return true;
        for (let i = 0; i < window.desktops.length; i++) {
            if (window.desktops[i] === Workspace.currentDesktop)
                return true;
        }
        return false;
    }

    // Gehört das Fenster in die Auswahl? Der Taskmanager wartet versteckt im Hintergrund – KWin führt ihn
    // dann als minimiertes Fenster ohne Bild (das war das leere Feld).
    function candidate(w, window, allScreens) {
        return w !== window && w.normalWindow && !w.deleted && w.managed !== false && !w.skipTaskbar
            && w.caption !== pickerTitle && (allScreens || w.output === window.output) && onDesktop(w)
            && w.frameGeometry.width > 0 && w.frameGeometry.height > 0
            && !(w.minimized && w.resourceClass === "easylinux-taskmanager");
    }

    // Liegt schon ein angedocktes Fenster in diesem Bereich? Geprüft wird, wo es wirklich steht:
    // die Kachel-Zuordnung bleibt z. B. nach dem Maximieren oder Verschieben manchmal hängen.
    function occupant(zone, source) {
        const stack = Workspace.stackingOrder;
        for (let i = stack.length - 1; i >= 0; i--) {
            const w = stack[i];
            if (w === source || !w.normalWindow || w.minimized || !w.tile || w.caption === pickerTitle || !onDesktop(w))
                continue;
            const f = w.frameGeometry;
            const ix = Math.min(f.x + f.width, zone.x + zone.width) - Math.max(f.x, zone.x);
            const iy = Math.min(f.y + f.height, zone.y + zone.height) - Math.max(f.y, zone.y);
            if (ix <= 0 || iy <= 0)
                continue;
            const overlap = ix * iy;
            if (overlap > zone.width * zone.height * 0.8 && overlap > f.width * f.height * 0.8)
                return w;
        }
        return null;
    }

    function tiled(window) {
        try {
            offer(window);
        } catch (e) {
            console.warn("easyLinux Snap Assist:", e);
        }
    }

    function offer(window) {
        if (Date.now() < busyUntil)
            return;
        closePickers();  // eine noch offene Auswahl vom letzten Andocken gilt nicht mehr
        if (!window.tile || window.minimized)
            return;
        const whenOccupied = setting("WhenOccupied", false);
        const area = Workspace.clientArea(KWin.MaximizeArea, window);
        const g = window.tile.absoluteGeometry;
        // Nur Hälften (ganze Höhe) und – falls eingeschaltet – Viertel; oben/unten und Raster lassen wir in Ruhe
        if (g.width < area.width * 0.35 || g.width > area.width * 0.65)
            return;
        const half = g.height > area.height * 0.9;
        const quarter = g.height > area.height * 0.35 && g.height < area.height * 0.65;
        if (!half && !(quarter && setting("Quarters", true)))
            return;
        const left = g.x - area.x < area.width * 0.1;
        const top = g.y - area.y < area.height * 0.1;

        // Die andere Seite: ganz frei → Hälfte, ein Viertel belegt → das andere Viertel, sonst belegt
        const col = left ? Qt.rect(g.x + g.width, area.y, area.x + area.width - g.x - g.width, area.height)
                         : Qt.rect(area.x, area.y, g.x - area.x, area.height);
        const split = half ? area.y + area.height / 2 : (top ? g.y + g.height : g.y);
        const colTop = Qt.rect(col.x, area.y, col.width, split - area.y);
        const colBottom = Qt.rect(col.x, split, col.width, area.y + area.height - split);
        const side = left ? "Right" : "Left";
        const zones = [], taken = [];
        const full = occupant(col, window), upper = occupant(colTop, window), lower = occupant(colBottom, window);
        if (full || (upper && lower)) {
            if (whenOccupied)
                zones.push({ rect: col, slot: side });
            taken.push(full, upper, lower);
        } else if (upper) {
            zones.push({ rect: colBottom, slot: "Bottom" + side });
            taken.push(upper);
        } else if (lower) {
            zones.push({ rect: colTop, slot: "Top" + side });
            taken.push(lower);
        } else {
            zones.push({ rect: col, slot: side });
        }
        // Viertel: zusätzlich das Viertel darüber bzw. darunter
        if (quarter) {
            const rest = top ? Qt.rect(g.x, g.y + g.height, g.width, area.y + area.height - g.y - g.height)
                             : Qt.rect(g.x, area.y, g.width, g.y - area.y);
            const other = occupant(rest, window);
            if (!other || whenOccupied)
                zones.push({ rect: rest, slot: (top ? "Bottom" : "Top") + (left ? "Left" : "Right") });
            taken.push(other);
        }
        if (zones.length === 0)
            return;

        // Fenster vom eigenen Bildschirm zuerst, jeweils zuletzt benutzte zuerst
        const allScreens = setting("AllScreens", true);
        const here = [], elsewhere = [];
        const stack = Workspace.stackingOrder;
        for (let i = stack.length - 1; i >= 0; i--) {
            const w = stack[i];
            if (candidate(w, window, allScreens) && taken.indexOf(w) < 0)
                (w.output === window.output ? here : elsewhere).push(w);
        }
        const candidates = here.concat(elsewhere);
        if (candidates.length === 0)
            return;
        zones.forEach((zone, i) => {
            zone.output = window.output;
            const loader = pickers[i];
            if (!loader.item)
                loader.source = "Picker.qml";
            loader.item.show(zone, candidates, window);
        });
    }

    function closePickers() {
        for (const loader of pickers) {
            if (loader.item)
                loader.item.close();
        }
    }

    function pick(window, zone) {
        closePickers();
        busyUntil = Date.now() + 600;
        try {
            window.minimized = false;
            // Ein schon angedocktes Fenster würde das Andock-Kürzel sonst weiterschieben (z. B. auf den Nachbarbildschirm)
            if (window.tile)
                window.tile.unmanage(window);
            if (window.output !== zone.output)
                Workspace.sendClientToScreen(window, zone.output);
            Workspace.activeWindow = window;
            Workspace["slotWindowQuickTile" + zone.slot]();
        } catch (e) {
            console.warn("easyLinux Snap Assist:", e);
        }
    }

    Loader { id: pickerA }
    Loader { id: pickerB }

    Connections {
        target: Workspace
        function onWindowAdded(window) { root.hook(window) }
        function onWindowRemoved(window) { root.hooks = root.hooks.filter(h => h[0] !== window) }
    }

    Component.onDestruction: {
        for (const [window, fn] of hooks) {
            try { window.tileChanged.disconnect(fn); } catch (e) {}
        }
    }

    Component.onCompleted: {
        const stack = Workspace.stackingOrder;
        for (let i = 0; i < stack.length; i++)
            hook(stack[i]);
    }
}
