/*
    Snap Assist für KWin (easyLinux): Wird ein Fenster an eine Bildschirmhälfte angedockt,
    erscheinen in der freien Hälfte die übrigen Fenster als Vorschau. Ein Klick dockt das
    gewählte Fenster dort an; Esc, ein Klick daneben oder ein Fensterwechsel bricht ab.
*/
import QtQuick
import org.kde.kwin

Item {
    id: root

    readonly property string pickerTitle: "easyLinux-Andock-Assistent"
    property bool busy: false      // während wir selbst andocken, nicht erneut anbieten
    property var hooks: []         // [Fenster, Funktion] – beim Entladen wieder lösen

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

    function tiled(window) {
        if (busy || !window.tile || window !== Workspace.activeWindow)
            return;
        const area = Workspace.clientArea(KWin.MaximizeArea, window);
        const g = window.tile.absoluteGeometry;
        // Nur bei einer Hälfte (links/rechts über die ganze Höhe) – Ecken und Raster lassen wir in Ruhe
        if (g.width < area.width * 0.35 || g.width > area.width * 0.65 || g.height < area.height * 0.9)
            return;
        const left = g.x - area.x < area.width * 0.1;
        const free = left ? Qt.rect(g.x + g.width, area.y, area.x + area.width - g.x - g.width, area.height)
                          : Qt.rect(area.x, area.y, g.x - area.x, area.height);
        const candidates = [];
        const stack = Workspace.stackingOrder;
        for (let i = stack.length - 1; i >= 0; i--) {  // zuletzt benutzte zuerst
            const w = stack[i];
            if (w === window || !w.normalWindow || w.caption === pickerTitle || w.skipTaskbar || w.output !== window.output || !onDesktop(w))
                continue;
            // Freie Hälfte ist schon belegt → nichts anbieten
            if (w.tile && !w.minimized) {
                const t = w.tile.absoluteGeometry;
                if (Math.abs(t.x - free.x) < 20 && Math.abs(t.width - free.width) < 20)
                    return;
            }
            candidates.push(w);
        }
        if (candidates.length === 0)
            return;
        if (!pickerLoader.item)
            pickerLoader.source = "Picker.qml";
        pickerLoader.item.show(free, candidates, !left);
    }

    function pick(window, toLeft) {
        busy = true;
        window.minimized = false;
        Workspace.activeWindow = window;
        if (toLeft)
            Workspace.slotWindowQuickTileLeft();
        else
            Workspace.slotWindowQuickTileRight();
        release.restart();
    }

    Timer { id: release; interval: 600; onTriggered: root.busy = false }

    Loader { id: pickerLoader }

    Connections {
        target: Workspace
        function onWindowAdded(window) { root.hook(window) }
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
