import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.System

DraggableDesktopWidget {
  id: root

  property var pluginApi: null

  defaultX: 2880
  defaultY: 1060

  // the base clips to the root's size — it does not auto-size to content
  implicitWidth: panel.width
  implicitHeight: panel.height
  width: implicitWidth
  height: implicitHeight

  // ── palette (scheme-driven) ──
  readonly property color cInk: Color.mOnSurface
  readonly property color cDim: Color.mOnSurfaceVariant
  readonly property color cFaint: Color.mOutline
  readonly property color cAmber: Color.mTertiary
  readonly property color cRed: Color.mError
  readonly property string monoFont: Settings.data.ui.fontFixed

  // ── data ──
  property var cpuHist: []
  property var memHist: []
  property real uptimeSecs: 0

  Component.onCompleted: SystemStatService.registerComponent("coldwire-monitor")
  Component.onDestruction: SystemStatService.unregisterComponent("coldwire-monitor")

  Process {
    id: uptimeProc
    command: ["cat", "/proc/uptime"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var v = parseFloat(text.split(" ")[0]);
        if (!isNaN(v))
          root.uptimeSecs = v;
      }
    }
  }

  Timer {
    // 1s heartbeat: history samples + uptime tick
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.uptimeSecs += 1;
      var c = root.cpuHist.slice();
      c.push(SystemStatService.cpuUsage);
      if (c.length > 90)
        c.shift();
      root.cpuHist = c;
      var m = root.memHist.slice();
      m.push(SystemStatService.memPercent);
      if (m.length > 90)
        m.shift();
      root.memHist = m;
    }
  }

  Timer {
    // resync real uptime every 5 min
    interval: 300000
    running: true
    repeat: true
    onTriggered: uptimeProc.running = true
  }

  function fmtUptime(s) {
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = Math.floor(s % 60);
    function p(n) { return (n < 10 ? "0" : "") + n; }
    return p(h) + ":" + p(m) + ":" + p(sec);
  }

  function fmtSpeed(b) {
    if (b > 1048576)
      return (b / 1048576).toFixed(1) + "M";
    if (b > 1024)
      return (b / 1024).toFixed(0) + "K";
    return b.toFixed(0) + "B";
  }

  Rectangle {
    id: panel
    width: 470
    height: 252
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.88)
    border.color: root.cFaint
    border.width: 1

    // ── corner tick marks ──
    Repeater {
      model: 4
      delegate: Item {
        id: tick
        readonly property bool onRight: index % 2 === 1
        readonly property bool onBottom: index > 1
        x: onRight ? panel.width - 9 : 3
        y: onBottom ? panel.height - 9 : 3
        Rectangle {
          width: 6; height: 1
          color: root.cDim
          y: tick.onBottom ? 5 : 0
        }
        Rectangle {
          width: 1; height: 6
          color: root.cDim
          x: tick.onRight ? 5 : 0
        }
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 6

      // ── header: decode label + uptime ──
      Item {
        width: parent.width
        height: 16

        Text {
          id: headerText
          anchors.left: parent.left
          font.family: root.monoFont
          font.pixelSize: 11
          font.letterSpacing: 1.5
          color: root.cInk
          property string target: "COLDWIRE // SYS_MONITOR"
          property int revealed: 0
          text: target
          Timer {
            id: decodeTimer
            interval: 28
            running: true
            repeat: true
            property string glyphs: "!<>-_\\/[]{}—=+*^?#________"
            onTriggered: {
              var t = headerText.target;
              headerText.revealed++;
              if (headerText.revealed >= t.length) {
                headerText.text = t;
                stop();
                return;
              }
              var out = t.substring(0, headerText.revealed);
              for (var i = headerText.revealed; i < t.length; i++) {
                out += t[i] === " " ? " " : glyphs[Math.floor(Math.random() * glyphs.length)];
              }
              headerText.text = out;
            }
          }
        }

        Text {
          anchors.right: parent.right
          font.family: root.monoFont
          font.pixelSize: 10
          color: root.cDim
          text: "UP " + root.fmtUptime(root.uptimeSecs)
        }
      }

      Rectangle { width: parent.width; height: 1; color: root.cFaint }

      // ── body: sparklines left, mesh right ──
      Row {
        width: parent.width
        height: 168
        spacing: 12

        Column {
          width: parent.width - mesh.width - 12
          height: parent.height
          spacing: 4

          SparkRow {
            label: "CPU"
            value: Math.round(SystemStatService.cpuUsage) + "%"
            values: root.cpuHist
            maxValue: 100
            threshold: 90
          }
          SparkRow {
            label: "MEM"
            value: Math.round(SystemStatService.memPercent) + "%"
            values: root.memHist
            maxValue: 100
            threshold: 90
          }
          SparkRow {
            label: "NET"
            value: "↓" + root.fmtSpeed(SystemStatService.rxSpeed) + " ↑" + root.fmtSpeed(SystemStatService.txSpeed)
            values: SystemStatService.rxSpeedHistory
            values2: SystemStatService.txSpeedHistory
            maxValue: 0 // autoscale
            threshold: -1
          }
        }

        // ── ambient wireframe icosahedron ──
        Canvas {
          id: mesh
          width: 128
          height: parent.height
          property real angle: 0
          property real wobble: 0

          Timer {
            interval: 66
            running: true
            repeat: true
            onTriggered: {
              mesh.angle += 0.008;
              mesh.wobble += 0.02;
              mesh.requestPaint();
            }
          }

          onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var phi = (1 + Math.sqrt(5)) / 2;
            var verts = [[-1, phi, 0], [1, phi, 0], [-1, -phi, 0], [1, -phi, 0], [0, -1, phi], [0, 1, phi], [0, -1, -phi], [0, 1, -phi], [phi, 0, -1], [phi, 0, 1], [-phi, 0, -1], [-phi, 0, 1]];
            var edges = [[0, 1], [0, 5], [0, 7], [0, 10], [0, 11], [1, 5], [1, 7], [1, 8], [1, 9], [2, 3], [2, 4], [2, 6], [2, 10], [2, 11], [3, 4], [3, 6], [3, 8], [3, 9], [4, 5], [4, 9], [4, 11], [5, 9], [5, 11], [6, 7], [6, 8], [6, 10], [7, 8], [7, 10], [8, 9], [10, 11]];
            var cx = width / 2, cy = height / 2;
            var scale = 26 + Math.sin(wobble) * 1.5;
            var ca = Math.cos(angle), sa = Math.sin(angle);
            var cb = Math.cos(angle * 0.7), sb = Math.sin(angle * 0.7);
            var proj = [];
            for (var i = 0; i < verts.length; i++) {
              var v = verts[i];
              // rotate Y then X, slight per-vertex breathing
              var r = 1 + 0.04 * Math.sin(wobble + i * 1.7);
              var x = v[0] * r, y = v[1] * r, z = v[2] * r;
              var x1 = x * ca + z * sa;
              var z1 = -x * sa + z * ca;
              var y1 = y * cb - z1 * sb;
              var z2 = y * sb + z1 * cb;
              var d = 1 / (1 + z2 * 0.12);
              proj.push([cx + x1 * scale * d, cy + y1 * scale * d, z2]);
            }
            for (var e = 0; e < edges.length; e++) {
              var a = proj[edges[e][0]], b = proj[edges[e][1]];
              var depth = (a[2] + b[2]) / 2;
              var alpha = 0.25 + 0.45 * (1 - (depth + 2) / 4);
              ctx.strokeStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, alpha);
              ctx.lineWidth = 1;
              ctx.beginPath();
              ctx.moveTo(a[0], a[1]);
              ctx.lineTo(b[0], b[1]);
              ctx.stroke();
            }
            // vertices as dots
            for (var p = 0; p < proj.length; p++) {
              ctx.fillStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 0.8);
              ctx.fillRect(proj[p][0] - 1, proj[p][1] - 1, 2, 2);
            }
          }

          Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.monoFont
            font.pixelSize: 8
            font.letterSpacing: 1
            color: root.cDim
            text: "MESH_04 // IDLE"
          }
        }
      }

      Rectangle { width: parent.width; height: 1; color: root.cFaint }

      // ── footer: hex ticker ──
      Text {
        id: hexTicker
        font.family: root.monoFont
        font.pixelSize: 9
        font.letterSpacing: 1
        color: root.cDim
        text: "0x0000 // 0000 // 0000"
        Timer {
          interval: 1100
          running: true
          repeat: true
          onTriggered: {
            function hx(n) {
              var s = "";
              for (var i = 0; i < n; i++)
                s += "0123456789ABCDEF"[Math.floor(Math.random() * 16)];
              return s;
            }
            hexTicker.text = "0x" + hx(4) + " // " + hx(4) + " // " + hx(4) + "  ·  T+" + Math.floor(root.uptimeSecs) + "s";
          }
        }
      }
    }
  }

  // ── sparkline row component ──
  component SparkRow: Item {
    id: row
    property string label: ""
    property string value: ""
    property var values: []
    property var values2: []
    property real maxValue: 100
    property real threshold: 90
    width: parent.width
    height: 52

    readonly property real lastVal: values.length ? values[values.length - 1] : 0
    readonly property bool hot: threshold > 0 && lastVal >= threshold

    Text {
      id: lbl
      font.family: root.monoFont
      font.pixelSize: 9
      font.letterSpacing: 1.5
      color: root.cDim
      text: row.label + " //"
    }
    Text {
      anchors.right: parent.right
      font.family: root.monoFont
      font.pixelSize: 9
      color: row.hot ? root.cRed : root.cAmber
      text: row.value
    }

    Canvas {
      id: spark
      anchors.top: lbl.bottom
      anchors.topMargin: 2
      width: parent.width
      height: parent.height - lbl.height - 4

      property var vals: row.values
      property var vals2: row.values2
      onValsChanged: requestPaint()
      onVals2Changed: requestPaint()

      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        // dotted baseline grid
        ctx.strokeStyle = Qt.rgba(root.cFaint.r, root.cFaint.g, root.cFaint.b, 0.6);
        ctx.setLineDash([1, 4]);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, height - 0.5);
        ctx.lineTo(width, height - 0.5);
        ctx.stroke();
        ctx.setLineDash([]);

        function drawSeries(vals, col, alpha) {
          if (!vals || vals.length < 2)
            return;
          var mx = row.maxValue;
          if (mx <= 0) {
            for (var i = 0; i < vals.length; i++)
              mx = Math.max(mx, vals[i]);
            mx = Math.max(mx, 1);
          }
          ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, alpha);
          ctx.lineWidth = 1;
          ctx.beginPath();
          var n = vals.length;
          for (var i = 0; i < n; i++) {
            var x = (i / (n - 1)) * (width - 2);
            var y = height - 1 - (Math.min(vals[i], mx) / mx) * (height - 3);
            if (i === 0)
              ctx.moveTo(x, y);
            else
              ctx.lineTo(x, y);
          }
          ctx.stroke();
        }

        drawSeries(spark.vals, row.hot ? root.cRed : root.cInk, 0.9);
        drawSeries(spark.vals2, root.cDim, 0.7);

        // amber current-value dot on primary series
        if (spark.vals && spark.vals.length > 1) {
          var mx2 = row.maxValue;
          if (mx2 <= 0) {
            for (var j = 0; j < spark.vals.length; j++)
              mx2 = Math.max(mx2, spark.vals[j]);
            mx2 = Math.max(mx2, 1);
          }
          var lx = width - 2;
          var lv = spark.vals[spark.vals.length - 1];
          var ly = height - 1 - (Math.min(lv, mx2) / mx2) * (height - 3);
          ctx.fillStyle = Qt.rgba(root.cAmber.r, root.cAmber.g, root.cAmber.b, 1);
          ctx.fillRect(lx - 1.5, ly - 1.5, 3, 3);
        }
      }
    }
  }
}
