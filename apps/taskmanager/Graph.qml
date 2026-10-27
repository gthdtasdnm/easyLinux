import QtQuick
import org.kde.kirigami as Kirigami

// Verlaufsdiagramm über 60 Messpunkte (0–100); history2 = zweite, gestrichelte Linie (z. B. Senden)
Canvas {
    id: graph
    property var history: []
    property var history2: []
    property color color: Kirigami.Theme.highlightColor
    property bool grid: true
    readonly property int points: 60

    onHistoryChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function line(ctx, h, fill, dashed) {
        if (!h || h.length < 2)
            return
        const n = points, x = i => width - (h.length - 1 - i) * width / (n - 1)
        const y = v => height - Math.max(0, Math.min(100, v)) / 100 * (height - 1)
        ctx.beginPath()
        ctx.moveTo(x(0), y(h[0]))
        for (let i = 1; i < h.length; i++)
            ctx.lineTo(x(i), y(h[i]))
        ctx.setLineDash(dashed ? [4, 3] : [])
        ctx.strokeStyle = graph.color
        ctx.lineWidth = 1.5
        ctx.stroke()
        if (fill) {
            ctx.lineTo(width, height)
            ctx.lineTo(x(0), height)
            ctx.closePath()
            ctx.fillStyle = Qt.alpha(graph.color, 0.18)
            ctx.fill()
        }
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = Qt.alpha(graph.color, 0.6)
        ctx.lineWidth = 1
        ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
        if (grid) {
            ctx.strokeStyle = Qt.alpha(graph.color, 0.15)
            for (let i = 1; i < 10; i++) {
                ctx.beginPath(); ctx.moveTo(0, i * height / 10); ctx.lineTo(width, i * height / 10); ctx.stroke()
            }
            for (let i = 1; i < 20; i++) {
                ctx.beginPath(); ctx.moveTo(i * width / 20, 0); ctx.lineTo(i * width / 20, height); ctx.stroke()
            }
        }
        line(ctx, history, true, false)
        line(ctx, history2, false, true)
    }
}
