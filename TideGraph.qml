import QtQuick
import "Model.js" as Model

// Line graph of one day's tide height, midnight to midnight, with the high
// and low waters labelled and a marker at the current time.
Canvas {
  id: graph

  property var tides: []
  property date dayStart: new Date()
  property date dayEnd: new Date()
  property date now: new Date()
  property color foreground: "white"
  property color accent: "white"
  property string fontFamily: "monospace"
  property var formatTime: function(t) { return Qt.formatTime(t, "h:mm") }
  property bool use24Hour: false

  onTidesChanged: requestPaint()
  onNowChanged: requestPaint()
  onForegroundChanged: requestPaint()
  onAccentChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function rgba(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    if (!tides || tides.length < 2) return

    var padL = 16, padR = 16, padT = 26, padB = 40
    var w = width - padL - padR
    var h = height - padT - padB
    var t0 = dayStart.getTime(), t1 = dayEnd.getTime()

    // Scale to the day's range with headroom, so small-range days still read.
    var maxH = -Infinity, minH = Infinity
    for (var i = 0; i < tides.length; i++) {
      maxH = Math.max(maxH, tides[i].height)
      minH = Math.min(minH, tides[i].height)
    }
    var span = Math.max(0.8, maxH - minH)
    maxH += span * 0.08
    minH -= span * 0.08

    function x(ms) { return padL + (ms - t0) / (t1 - t0) * w }
    function y(m) { return padT + (1 - (m - minH) / (maxH - minH)) * h }

    // Hour grid with labels every six hours.
    ctx.font = "11px '" + fontFamily + "'"
    ctx.textAlign = "center"
    ctx.textBaseline = "top"
    for (var hr = 0; hr <= 24; hr += 3) {
      var gx = x(new Date(dayStart.getFullYear(), dayStart.getMonth(), dayStart.getDate(), hr).getTime())
      ctx.strokeStyle = rgba(foreground, hr % 6 === 0 ? 0.12 : 0.05)
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(gx, padT - 8)
      ctx.lineTo(gx, padT + h)
      ctx.stroke()
      if (hr % 6 === 0) {
        ctx.fillStyle = rgba(foreground, 0.45)
        var lbl = use24Hour ? (hr < 10 ? "0" : "") + (hr % 24) + ":00"
                            : ((hr % 12) || 12) + (hr % 24 < 12 ? "am" : "pm")
        ctx.fillText(lbl, gx, padT + h + 20)
      }
    }

    // Curve, sampled every 10 minutes.
    var pts = []
    for (var ms = t0; ms <= t1; ms += 10 * 60000) {
      var v = Model.heightAt(tides, new Date(ms))
      if (v !== null) pts.push([x(ms), y(v)])
    }
    if (pts.length < 2) return

    var grad = ctx.createLinearGradient(0, padT, 0, padT + h)
    grad.addColorStop(0, rgba(accent, 0.30))
    grad.addColorStop(1, rgba(accent, 0.02))
    ctx.beginPath()
    ctx.moveTo(pts[0][0], padT + h)
    for (var p = 0; p < pts.length; p++) ctx.lineTo(pts[p][0], pts[p][1])
    ctx.lineTo(pts[pts.length - 1][0], padT + h)
    ctx.closePath()
    ctx.fillStyle = grad
    ctx.fill()

    ctx.beginPath()
    ctx.moveTo(pts[0][0], pts[0][1])
    for (var q = 1; q < pts.length; q++) ctx.lineTo(pts[q][0], pts[q][1])
    ctx.strokeStyle = rgba(accent, 1)
    ctx.lineWidth = 2
    ctx.lineJoin = "round"
    ctx.stroke()

    // High and low waters within the day.
    for (var k = 0; k < tides.length; k++) {
      var t = tides[k]
      var tm = t.time.getTime()
      if (tm < t0 || tm > t1) continue
      var px = x(tm), py = y(t.height)
      ctx.fillStyle = rgba(accent, 1)
      ctx.beginPath()
      ctx.arc(px, py, 3.5, 0, Math.PI * 2)
      ctx.fill()

      ctx.textAlign = px < padL + 30 ? "left" : (px > padL + w - 30 ? "right" : "center")
      ctx.fillStyle = rgba(foreground, 0.85)
      var label = formatTime(t.time) + "  " + Number(t.height).toFixed(2)
      if (t.high) {
        ctx.textBaseline = "bottom"
        ctx.fillText(label, px, py - 7)
      } else {
        ctx.textBaseline = "top"
        ctx.fillText(label, px, py + 7)
      }
    }

    // Now marker.
    var nm = now.getTime()
    if (nm >= t0 && nm <= t1) {
      var nv = Model.heightAt(tides, now)
      var nx = x(nm)
      ctx.strokeStyle = rgba(foreground, 0.5)
      ctx.lineWidth = 1
      ctx.setLineDash([3, 3])
      ctx.beginPath()
      ctx.moveTo(nx, padT - 8)
      ctx.lineTo(nx, padT + h)
      ctx.stroke()
      ctx.setLineDash([])
      if (nv !== null) {
        ctx.fillStyle = rgba(foreground, 1)
        ctx.beginPath()
        ctx.arc(nx, y(nv), 4.5, 0, Math.PI * 2)
        ctx.fill()
      }
    }
  }
}
