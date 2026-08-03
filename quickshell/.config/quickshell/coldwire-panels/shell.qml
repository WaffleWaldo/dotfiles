// Coldwire panels — tileable widget windows for niri.
// Run: qs -c coldwire-panels   (windows: coldwire-clock, coldwire-mesh, coldwire-stats)
// Self-contained: polls /proc directly, no noctalia dependency.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  id: root

  // ── Coldwire palette (source: Dev/Coldwire/Coldwire Style Guide.md) ──
  readonly property color cBg: "#050505"
  readonly property color cPanel: "#0A0A0A"
  readonly property color cFaint: "#1A1A1A"
  readonly property color cLine: "#333333"
  readonly property color cDim: "#8A8A8A"
  readonly property color cInk: "#C8C8C8"
  readonly property color cBright: "#F2F2F0"
  readonly property color cAmber: "#FFB000"
  readonly property color cRed: "#FF3B30"
  readonly property real panelAlpha: 0.80
  readonly property string mono: "JetBrains Mono"

  // ══ telemetry engine ══
  property var cpuHist: []
  property var memHist: []
  property var rxHist: []
  property var txHist: []
  property real cpuNow: 0
  property real memNow: 0
  property real rxNow: 0
  property real txNow: 0
  property real load1: 0
  property real uptimeSecs: 0
  property var _prevCpu: null
  property var _prevNet: null

  function pushHist(arr, v) {
    var a = arr.slice();
    a.push(v);
    if (a.length > 120)
      a.shift();
    return a;
  }

  Process {
    id: pollProc
    command: ["sh", "-c", "cat /proc/stat /proc/meminfo /proc/net/dev /proc/loadavg /proc/uptime"]
    stdout: StdioCollector {
      onStreamFinished: root.ingest(text)
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: pollProc.running = true
  }

  function ingest(text) {
    var lines = text.split("\n");
    var memTotal = 0, memAvail = 0;
    var rx = 0, tx = 0;
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i];
      if (l.indexOf("cpu ") === 0) {
        var f = l.trim().split(/\s+/).slice(1).map(Number);
        var idle = f[3] + f[4];
        var total = f.reduce((a, b) => a + b, 0);
        if (_prevCpu) {
          var dt = total - _prevCpu[1];
          cpuNow = dt > 0 ? Math.max(0, Math.min(100, 100 * (1 - (idle - _prevCpu[0]) / dt))) : 0;
        }
        _prevCpu = [idle, total];
      } else if (l.indexOf("MemTotal:") === 0) {
        memTotal = parseInt(l.split(/\s+/)[1]);
      } else if (l.indexOf("MemAvailable:") === 0) {
        memAvail = parseInt(l.split(/\s+/)[1]);
      } else if (l.indexOf(":") > 0 && l.indexOf("|") < 0 && /^\s*(en|wl|eth|bond|br)/.test(l)) {
        var parts = l.split(":")[1].trim().split(/\s+/).map(Number);
        rx += parts[0];
        tx += parts[8];
      } else if (/^[\d.]+ [\d.]+ [\d.]+ \d+\/\d+/.test(l)) {
        load1 = parseFloat(l.split(" ")[0]);
      } else if (/^[\d.]+ [\d.]+\s*$/.test(l)) {
        uptimeSecs = parseFloat(l.split(" ")[0]);
      }
    }
    if (memTotal > 0)
      memNow = 100 * (1 - memAvail / memTotal);
    if (_prevNet) {
      rxNow = Math.max(0, rx - _prevNet[0]);
      txNow = Math.max(0, tx - _prevNet[1]);
      rxHist = pushHist(rxHist, rxNow);
      txHist = pushHist(txHist, txNow);
    }
    _prevNet = [rx, tx];
    cpuHist = pushHist(cpuHist, cpuNow);
    memHist = pushHist(memHist, memNow);
  }

  function fmtSpeed(b) {
    if (b > 1048576)
      return (b / 1048576).toFixed(1) + "M";
    if (b > 1024)
      return (b / 1024).toFixed(0) + "K";
    return b.toFixed(0) + "B";
  }

  function fmtUptime(s) {
    function p(n) { return (n < 10 ? "0" : "") + n; }
    return p(Math.floor(s / 3600)) + ":" + p(Math.floor((s % 3600) / 60)) + ":" + p(Math.floor(s % 60));
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // ══ reusable chrome ══
  component PanelFrame: Rectangle {
    color: Qt.rgba(root.cPanel.r, root.cPanel.g, root.cPanel.b, root.panelAlpha)
    // niri draws the outer hairline; we add corner ticks only
    Repeater {
      model: 4
      delegate: Item {
        id: tick
        readonly property bool onRight: index % 2 === 1
        readonly property bool onBottom: index > 1
        x: onRight ? parent.width - 10 : 4
        y: onBottom ? parent.height - 10 : 4
        Rectangle { width: 6; height: 1; color: root.cDim; y: tick.onBottom ? 5 : 0 }
        Rectangle { width: 1; height: 6; color: root.cDim; x: tick.onRight ? 5 : 0 }
      }
    }
  }

  component MicroLabel: Text {
    font.family: root.mono
    font.pixelSize: 10
    font.letterSpacing: 1.5
    color: root.cDim
  }

  component DecodeText: Text {
    id: dt
    property string target: ""
    font.family: root.mono
    font.pixelSize: 11
    font.letterSpacing: 1.5
    color: root.cBright
    text: target
    property int revealed: 0
    Timer {
      interval: 26
      running: true
      repeat: true
      property string glyphs: "!<>-_\\/[]{}=+*^?#________"
      onTriggered: {
        dt.revealed++;
        if (dt.revealed >= dt.target.length) {
          dt.text = dt.target;
          stop();
          return;
        }
        var out = dt.target.substring(0, dt.revealed);
        for (var i = dt.revealed; i < dt.target.length; i++)
          out += dt.target[i] === " " ? " " : glyphs[Math.floor(Math.random() * glyphs.length)];
        dt.text = out;
      }
    }
  }

  component Spark: Canvas {
    id: spark
    property var vals: []
    property var vals2: []
    property real maxValue: 100
    property real threshold: 90
    readonly property real lastVal: vals.length ? vals[vals.length - 1] : 0
    readonly property bool hot: threshold > 0 && lastVal >= threshold
    onValsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();
      ctx.strokeStyle = Qt.rgba(root.cLine.r, root.cLine.g, root.cLine.b, 0.6);
      ctx.setLineDash([1, 4]);
      ctx.beginPath();
      ctx.moveTo(0, height - 0.5);
      ctx.lineTo(width, height - 0.5);
      ctx.stroke();
      ctx.setLineDash([]);
      function draw(vs, col, alpha) {
        if (!vs || vs.length < 2)
          return 0;
        var mx = spark.maxValue;
        if (mx <= 0) {
          for (var i = 0; i < vs.length; i++)
            mx = Math.max(mx, vs[i]);
          mx = Math.max(mx, 1);
        }
        ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, alpha);
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (var i = 0; i < vs.length; i++) {
          var x = (i / (vs.length - 1)) * (width - 2);
          var y = height - 1 - (Math.min(vs[i], mx) / mx) * (height - 3);
          i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
        }
        ctx.stroke();
        return mx;
      }
      var mx = draw(spark.vals, spark.hot ? root.cRed : root.cInk, 0.9);
      draw(spark.vals2, root.cDim, 0.7);
      if (spark.vals && spark.vals.length > 1) {
        var lv = spark.vals[spark.vals.length - 1];
        var ly = height - 1 - (Math.min(lv, mx) / mx) * (height - 3);
        ctx.fillStyle = root.cAmber;
        ctx.fillRect(width - 3.5, ly - 1.5, 3, 3);
      }
    }
  }

  // ══ window: clock ══
  FloatingWindow {
    title: "coldwire-clock"
    implicitWidth: 560
    implicitHeight: 240
    color: "transparent"

    PanelFrame {
      anchors.fill: parent

      Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          font.family: root.mono
          font.pixelSize: Math.min(parent.parent.width / 6.4, parent.parent.height / 2.6)
          font.letterSpacing: 4
          color: root.cBright
          text: Qt.formatDateTime(clock.date, "HH:mm:ss")
        }
        MicroLabel {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Qt.formatDateTime(clock.date, "ddd dd MMM yyyy").toUpperCase() + "  //  UP " + root.fmtUptime(root.uptimeSecs)
        }
      }

      DecodeText {
        x: 14; y: 10
        target: "COLDWIRE // CHRONO"
      }
      MicroLabel {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: "LOAD " + root.load1.toFixed(2)
        color: root.load1 > 12 ? root.cRed : root.cDim
      }
    }
  }

  // ══ window: mesh ══
  FloatingWindow {
    title: "coldwire-mesh"
    implicitWidth: 560
    implicitHeight: 420
    color: "transparent"

    PanelFrame {
      anchors.fill: parent

      DecodeText {
        x: 14; y: 10
        target: "COLDWIRE // MESH_04"
      }
      MicroLabel {
        id: meshState
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: "AMBIENT"
        color: root.cAmber
      }

      Canvas {
        id: mesh
        anchors.fill: parent
        anchors.topMargin: 30
        anchors.bottomMargin: 26
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
          var scale = Math.min(width, height) * 0.30 * (1 + 0.02 * Math.sin(wobble));
          var ca = Math.cos(angle), sa = Math.sin(angle);
          var cb = Math.cos(angle * 0.7), sb = Math.sin(angle * 0.7);
          var proj = [];
          for (var i = 0; i < verts.length; i++) {
            var r = 1 + 0.04 * Math.sin(wobble + i * 1.7);
            var x = verts[i][0] * r, y = verts[i][1] * r, z = verts[i][2] * r;
            var x1 = x * ca + z * sa;
            var z1 = -x * sa + z * ca;
            var y1 = y * cb - z1 * sb;
            var z2 = y * sb + z1 * cb;
            var d = 1 / (1 + z2 * 0.12);
            proj.push([cx + x1 * scale * d / 1.6, cy + y1 * scale * d / 1.6, z2]);
          }
          for (var e = 0; e < edges.length; e++) {
            var a = proj[edges[e][0]], b = proj[edges[e][1]];
            var depth = (a[2] + b[2]) / 2;
            ctx.strokeStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 0.25 + 0.45 * (1 - (depth + 2) / 4));
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(a[0], a[1]);
            ctx.lineTo(b[0], b[1]);
            ctx.stroke();
          }
          ctx.fillStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 0.8);
          for (var p = 0; p < proj.length; p++)
            ctx.fillRect(proj[p][0] - 1, proj[p][1] - 1, 2, 2);
        }
      }

      MicroLabel {
        id: hexTicker
        x: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        font.pixelSize: 9
        text: "0x0000 // 0000"
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
            hexTicker.text = "0x" + hx(4) + " // " + hx(4) + " // " + hx(4);
          }
        }
      }
    }
  }

  // ══ window: stats ══
  FloatingWindow {
    title: "coldwire-stats"
    implicitWidth: 560
    implicitHeight: 420
    color: "transparent"

    PanelFrame {
      anchors.fill: parent

      DecodeText {
        x: 14; y: 10
        target: "COLDWIRE // TELEMETRY"
      }
      MicroLabel {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: "T+" + Math.floor(root.uptimeSecs) + "s"
      }

      Rectangle {
        x: 14; y: 30
        width: parent.width - 28
        height: 1
        color: root.cFaint
      }

      Column {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 38
        spacing: 6

        Repeater {
          model: [
            { label: "CPU", isNet: false },
            { label: "MEM", isNet: false },
            { label: "NET", isNet: true }
          ]
          delegate: Item {
            required property var modelData
            width: parent.width
            height: (parent.height - 12) / 3

            MicroLabel {
              id: rowLbl
              text: modelData.label + " //"
            }
            Text {
              anchors.right: parent.right
              font.family: root.mono
              font.pixelSize: 10
              color: modelData.isNet ? root.cAmber
                     : ((modelData.label === "CPU" ? root.cpuNow : root.memNow) >= 90 ? root.cRed : root.cAmber)
              text: modelData.isNet
                    ? "↓" + root.fmtSpeed(root.rxNow) + " ↑" + root.fmtSpeed(root.txNow)
                    : Math.round(modelData.label === "CPU" ? root.cpuNow : root.memNow) + "%"
            }
            Spark {
              anchors.top: rowLbl.bottom
              anchors.topMargin: 3
              width: parent.width
              height: parent.height - rowLbl.height - 6
              vals: modelData.isNet ? root.rxHist : (modelData.label === "CPU" ? root.cpuHist : root.memHist)
              vals2: modelData.isNet ? root.txHist : []
              maxValue: modelData.isNet ? 0 : 100
              threshold: modelData.isNet ? -1 : 90
            }
          }
        }
      }
    }
  }
}
