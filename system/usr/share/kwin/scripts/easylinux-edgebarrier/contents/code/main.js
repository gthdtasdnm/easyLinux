/*
    Mausbarriere zwischen Bildschirmen nur, während ein Fenster gezogen wird – sonst läuft die Maus frei.
    KWin-Skripte können keine Einstellungen schreiben, deshalb setzt die User-Unit
    easylinux-edgebarrier@<Pixel>.service den Wert in kwinrc und lädt KWin neu.
    JavaScript statt QML: nur hier gibt es callDBus.
*/
const barrier = 15;   // Pixel, die die Maus beim Fensterziehen am Rand hängen bleibt

function setBarrier(px) {
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager",
             "StartUnit", "easylinux-edgebarrier@" + px + ".service", "replace");
}

function hook(w) {
    if (!w.normalWindow) return;
    w.interactiveMoveResizeStarted.connect(() => { if (w.move) setBarrier(barrier); });
    w.interactiveMoveResizeFinished.connect(() => setBarrier(0));
}

workspace.windowAdded.connect(hook);
workspace.stackingOrder.forEach(hook);
