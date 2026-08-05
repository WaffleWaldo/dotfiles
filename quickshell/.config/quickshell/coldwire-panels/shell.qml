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

  // ══ window: neural map (live Obsidian vault graph) ══
  FloatingWindow {
    title: "coldwire-net"
    implicitWidth: 1300
    implicitHeight: 800
    color: "transparent"

    PanelFrame {
      anchors.fill: parent

      DecodeText {
        x: 14; y: 10
        target: "COLDWIRE // VAULT_MAP"
      }
      MicroLabel {
        id: netMeta
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: "LOADING"
      }

      // regenerate from the vault, then load
      Process {
        id: graphLoader
        command: ["sh", "-c", "python3 ~/dotfiles/extras/coldwire-vaultmap.py >/dev/null 2>&1; cat ~/.cache/coldwire/vault-graph.json 2>/dev/null"]
        running: true
        stdout: StdioCollector {
          onStreamFinished: {
            try {
              var g = JSON.parse(text);
              net.nodes = g.nodes;
              net.links = g.links;
              // adjacency map: O(1) neighbor checks in the paint loop
              var nb = {};
              for (var li = 0; li < g.links.length; li++) {
                var a = g.links[li][0], b = g.links[li][1];
                (nb[a] = nb[a] || {})[b] = true;
                (nb[b] = nb[b] || {})[a] = true;
              }
              net.nbrs = nb;
              netMeta.text = "NOTES " + g.nodes.length + " // LINKS " + g.links.length;
            } catch (e) {
              netMeta.text = "NO VAULT DATA";
            }
          }
        }
      }
      Timer {
        // refresh the map every 10 min (vault changes)
        interval: 600000
        running: true
        repeat: true
        onTriggered: graphLoader.running = true
      }

      Canvas {
        id: net
        anchors.fill: parent
        anchors.topMargin: 30
        anchors.bottomMargin: 10
        renderStrategy: Canvas.Cooperative
        property real t: 0
        property var nodes: []
        property var links: []
        property var pulses: []
        property var nbrs: ({})
        property int hoverIdx: -1
        property int dragIdx: -1
        property bool dragged: false
        // ── 3D camera ──
        property real yaw: 0.55
        property real pitch: 0.30
        property real zoom: 1.0
        property bool orbiting: false
        property real lastMx: 0
        property real lastMy: 0
        property int idleTicks: 999

        Timer {
          interval: 66
          running: true
          repeat: true
          onTriggered: {
            net.t += 0.04;
            net.idleTicks++;
            if (net.idleTicks > 75)      // ~5s untouched: resume ambient orbit
              net.yaw += 0.0016;
            if (net.links.length && Math.random() < 0.05)
              net.pulses.push({ link: Math.floor(Math.random() * net.links.length), p: 0 });
            for (var i = net.pulses.length - 1; i >= 0; i--) {
              net.pulses[i].p += 0.025;
              if (net.pulses[i].p >= 1)
                net.pulses.splice(i, 1);
            }
            net.requestPaint();
          }
        }

        // project one node through the current camera; returns [sx, sy, depth, perspective]
        function pos(n, i) {
          var wx = n.x - 0.5 + 0.008 * Math.sin(t * (0.5 + (i % 7) * 0.09) + i);
          var wy = n.y - 0.5 + 0.008 * Math.cos(t * (0.4 + (i % 5) * 0.11) + i * 1.7);
          var wz = (n.z !== undefined ? n.z : 0.5) - 0.5 + 0.008 * Math.sin(t * 0.45 + i * 2.3);
          var cy_ = Math.cos(yaw), sy_ = Math.sin(yaw);
          var cp_ = Math.cos(pitch), sp_ = Math.sin(pitch);
          var x1 = wx * cy_ + wz * sy_;
          var z1 = -wx * sy_ + wz * cy_;
          var y1 = wy * cp_ - z1 * sp_;
          var z2 = wy * sp_ + z1 * cp_;
          var S = Math.min(width, height) * 1.02 * zoom;
          var per = 1 / (1 + z2 * 0.65);
          return [width / 2 + x1 * S * per, height / 2 + y1 * S * per, z2, per];
        }

        function nodeAt(mx, my) {
          var best = -1, bestD = 15 * 15;
          for (var i = 0; i < nodes.length; i++) {
            var p = pos(nodes[i], i);
            var dx = p[0] - mx, dy = p[1] - my;
            var d2 = dx * dx + dy * dy;
            if (d2 < bestD) {
              bestD = d2;
              best = i;
            }
          }
          return best;
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: net.hoverIdx >= 0 ? Qt.PointingHandCursor
                       : (net.orbiting ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
          onPressed: mouse => {
            net.idleTicks = 0;
            net.dragged = false;
            net.lastMx = mouse.x;
            net.lastMy = mouse.y;
            net.dragIdx = net.nodeAt(mouse.x, mouse.y);
            net.orbiting = net.dragIdx < 0;
          }
          onPositionChanged: mouse => {
            net.idleTicks = 0;
            var dx = mouse.x - net.lastMx;
            var dy = mouse.y - net.lastMy;
            if (net.orbiting) {
              net.yaw += dx * 0.008;
              net.pitch = Math.max(-1.35, Math.min(1.35, net.pitch + dy * 0.008));
              net.dragged = true;
              net.lastMx = mouse.x;
              net.lastMy = mouse.y;
              net.requestPaint();
            } else if (net.dragIdx >= 0) {
              // move the node in the camera plane at its current depth
              var n = net.nodes[net.dragIdx];
              var pcur = net.pos(n, net.dragIdx);
              var S = Math.min(net.width, net.height) * 1.02 * net.zoom;
              var ux = dx / (S * pcur[3]);
              var uy = dy / (S * pcur[3]);
              var cy_ = Math.cos(net.yaw), sy_ = Math.sin(net.yaw);
              var cp_ = Math.cos(net.pitch), sp_ = Math.sin(net.pitch);
              // inverse pitch, then inverse yaw, applied to (ux, uy, 0)
              var vy = uy * cp_;
              var vz = uy * sp_;
              var vx = ux * cy_ - vz * sy_;
              var vz2 = ux * sy_ + vz * cy_;
              n.x = Math.max(0.02, Math.min(0.98, n.x + vx));
              n.y = Math.max(0.02, Math.min(0.98, n.y + vy));
              n.z = Math.max(0.02, Math.min(0.98, (n.z !== undefined ? n.z : 0.5) + vz2));
              net.dragged = true;
              net.lastMx = mouse.x;
              net.lastMy = mouse.y;
              net.requestPaint();
            } else {
              var h = net.nodeAt(mouse.x, mouse.y);
              if (h !== net.hoverIdx) {
                net.hoverIdx = h;
                net.requestPaint();
              }
            }
          }
          onReleased: {
            if (net.dragIdx >= 0 && !net.dragged) {
              var n = net.nodes[net.dragIdx];
              Qt.openUrlExternally("obsidian://open?vault=brain&file=" + encodeURIComponent(n.p));
            }
            net.dragIdx = -1;
            net.orbiting = false;
          }
          onExited: net.hoverIdx = -1
          onWheel: wheel => {
            net.idleTicks = 0;
            var factor = wheel.angleDelta.y > 0 ? 1.12 : 1 / 1.12;
            net.zoom = Math.max(0.35, Math.min(4.0, net.zoom * factor));
            net.requestPaint();
          }
          onDoubleClicked: mouse => {
            // double-click empty space: camera home
            if (net.nodeAt(mouse.x, mouse.y) < 0) {
              net.yaw = 0.55;
              net.pitch = 0.30;
              net.zoom = 1.0;
              net.requestPaint();
            }
          }
        }

        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          if (!nodes.length)
            return;
          var pts = [];
          for (var i = 0; i < nodes.length; i++)
            pts.push(pos(nodes[i], i));
          var focusIdx = dragIdx >= 0 ? dragIdx : hoverIdx;
          // links, depth-faded (near links brighter)
          for (var l = 0; l < links.length; l++) {
            var la = links[l][0], lb = links[l][1];
            var a = pts[la], b = pts[lb];
            var depth = (a[2] + b[2]) / 2;              // -0.9 near .. 0.9 far? (sign: +z2 = away)
            var depthA = 0.10 + 0.14 * (1 - (depth + 0.9) / 1.8);
            var lit = focusIdx >= 0 && (la === focusIdx || lb === focusIdx);
            if (lit) {
              ctx.strokeStyle = Qt.rgba(root.cAmber.r, root.cAmber.g, root.cAmber.b, 0.55);
            } else {
              ctx.strokeStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, focusIdx >= 0 ? depthA * 0.5 : depthA);
            }
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(a[0], a[1]);
            ctx.lineTo(b[0], b[1]);
            ctx.stroke();
          }
          // pulses
          for (var p = 0; p < pulses.length; p++) {
            var lk = links[pulses[p].link];
            var a2 = pts[lk[0]], b2 = pts[lk[1]];
            ctx.fillStyle = Qt.rgba(root.cAmber.r, root.cAmber.g, root.cAmber.b, 0.9);
            ctx.fillRect(a2[0] + (b2[0] - a2[0]) * pulses[p].p - 1.5,
                         a2[1] + (b2[1] - a2[1]) * pulses[p].p - 1.5, 3, 3);
          }
          // nodes far -> near so close ones draw on top
          var order = [];
          for (var i = 0; i < nodes.length; i++)
            order.push(i);
          order.sort(function (u, v) { return pts[v][2] - pts[u][2]; });
          ctx.font = "8px \"" + root.mono + "\"";
          for (var oi = 0; oi < order.length; oi++) {
            var i = order[oi];
            var n = nodes[i];
            var per = pts[i][3];
            var sz = (2 + Math.min(n.d * 0.4, 5)) * per;
            var isFocus = i === focusIdx;
            var neighbor = focusIdx >= 0 && !isFocus && nbrs[focusIdx] !== undefined && nbrs[focusIdx][i] === true;
            var depthGlow = 0.35 + 0.65 * (1 - (pts[i][2] + 0.9) / 1.8);
            var c = n.a ? root.cAmber : (n.d >= 4 ? root.cBright : root.cDim);
            var alpha = focusIdx >= 0 && !isFocus && !neighbor ? 0.25 : (n.a ? 1 : 0.85) * Math.min(depthGlow + 0.25, 1);
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, alpha);
            ctx.fillRect(pts[i][0] - sz / 2, pts[i][1] - sz / 2, sz, sz);
            if (isFocus) {
              ctx.strokeStyle = Qt.rgba(root.cAmber.r, root.cAmber.g, root.cAmber.b, 0.9);
              ctx.lineWidth = 1;
              ctx.strokeRect(pts[i][0] - sz / 2 - 4, pts[i][1] - sz / 2 - 4, sz + 8, sz + 8);
            }
            if (isFocus || neighbor || (focusIdx < 0 && n.a)) {
              ctx.fillStyle = isFocus
                ? Qt.rgba(root.cBright.r, root.cBright.g, root.cBright.b, 1)
                : Qt.rgba(root.cDim.r, root.cDim.g, root.cDim.b, 0.6 + 0.3 * depthGlow);
              ctx.fillText(n.n.length > 24 ? n.n.slice(0, 23) + "…" : n.n,
                           pts[i][0] + sz / 2 + 5, pts[i][1] + 3);
            }
          }
        }
      }
    }
  }

  // ══ window: audio tap ══
  FloatingWindow {
    title: "coldwire-wave"
    implicitWidth: 1500
    implicitHeight: 400
    color: "transparent"

    PanelFrame {
      anchors.fill: parent

      DecodeText {
        x: 14; y: 10
        target: "COLDWIRE // AUDIO_TAP"
      }
      MicroLabel {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: wave.live ? "LIVE" : "SYNTH // IDLE"
        color: wave.live ? root.cAmber : root.cDim
      }

      Canvas {
        id: wave
        anchors.fill: parent
        anchors.topMargin: 30
        anchors.bottomMargin: 8
        renderStrategy: Canvas.Cooperative
        property real t: 0
        property real level: 0          // smoothed loudness 0..1
        property real lastSignal: 0
        property var ripples: []        // {r, amp} expanding rings
        property real sinceRipple: 99
        readonly property bool live: lastSignal > 0
        readonly property int rows: 46
        readonly property int cols: 150

        Process {
          id: cavaProc
          command: ["cava", "-p", Quickshell.shellDir + "/cava_raw.conf"]
          running: true
          stdout: SplitParser {
            onRead: line => {
              var vals = line.split(";").filter(s => s.length).map(Number);
              if (!vals.length)
                return;
              var sum = 0, mx = 0;
              for (var i = 0; i < vals.length; i++) {
                var v = Math.min(vals[i], 100) / 100;
                sum += v * v;
                if (vals[i] > mx)
                  mx = vals[i];
              }
              // hot sensitivity: RMS boosted hard, fast attack / slow release
              var lvl = Math.min(Math.sqrt(sum / vals.length) * 3.2, 1);
              wave.level = lvl > wave.level ? lvl : wave.level * 0.92;
              if (mx > 2)
                wave.lastSignal = 30;
              else if (wave.lastSignal > 0)
                wave.lastSignal -= 0.35;
            }
          }
        }

        Timer {
          interval: 40
          running: true
          repeat: true
          onTriggered: {
            wave.t += 0.035;
            wave.sinceRipple += 0.04;
            // drop a ring at the epicenter while audio plays
            if (wave.live && wave.level > 0.10 && wave.sinceRipple > 0.24) {
              wave.ripples.push({ r: 0.02, amp: Math.min(wave.level * 1.3, 1) });
              wave.sinceRipple = 0;
            }
            for (var i = wave.ripples.length - 1; i >= 0; i--) {
              wave.ripples[i].r += 0.016;
              wave.ripples[i].amp *= 0.955;
              if (wave.ripples[i].amp < 0.04 || wave.ripples[i].r > 1.5)
                wave.ripples.splice(i, 1);
            }
            wave.requestPaint();
          }
        }

        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          var w = width, h = height;
          var horizon = h * 0.14;
          var amberPts = [];
          var rip = ripples;
          var lvl = level;
          ctx.fillStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 1);
          for (var r = 0; r < rows; r++) {
            var z = r / (rows - 1);                        // 0 far, 1 near
            var ybase = horizon + Math.pow(z, 1.5) * h * 0.82;
            var spread = 0.60 + 0.50 * z;
            var depthScale = 0.30 + 0.70 * z;              // px lift grows toward viewer
            var rowGlow = 0.20 + 0.70 * Math.pow(z, 0.9);
            var sz = z < 0.35 ? 1 : 2;
            for (var c = 0; c < cols; c++) {
              var x01 = c / (cols - 1);
              // radial distance from the plane's exact center (aspect-weighted)
              var dx = (x01 - 0.5) * 1.9;
              var dz = z - 0.5;
              var d = Math.sqrt(dx * dx + dz * dz);
              // calm ambient swell
              var swell = 0.5 * Math.sin(x01 * 7.3 + t * 0.8 + z * 3.1)
                        + 0.3 * Math.sin(x01 * 13.7 - t * 1.2 + z * 1.7)
                        + 0.2 * Math.sin(x01 * 23.0 + t * 1.8 - z * 4.2);
              var lift = (swell + 1) * 14;                 // gentle base sea
              // the mountain: audio raises a sharp peak at dead center
              var mountain = lvl * Math.exp(-(d * d) / (0.045 * 0.045 * 2));
              lift += mountain * 260;
              // expanding rings from the drop point
              var ringSum = 0;
              for (var q = 0; q < rip.length; q++) {
                var rr = d - rip[q].r;
                ringSum += rip[q].amp * Math.exp(-(rr * rr) / (0.024 * 0.024 * 2));
              }
              lift += ringSum * 95;
              var sx = (x01 - 0.5) * spread * w * 1.30 + w / 2;
              var sy = ybase - lift * depthScale;
              var energy = mountain + ringSum * 0.8;
              ctx.globalAlpha = Math.min(rowGlow * (0.32 + 0.30 * (swell * 0.5 + 0.5) + 1.4 * energy), 1);
              ctx.fillRect(sx, sy, sz, sz);
              if (energy > 0.55)
                amberPts.push([sx, sy - 2, sz]);
            }
          }
          // amber: the peak cap and the strongest ring crests
          ctx.globalAlpha = 0.95;
          ctx.fillStyle = Qt.rgba(root.cAmber.r, root.cAmber.g, root.cAmber.b, 1);
          for (var i = 0; i < amberPts.length; i++)
            ctx.fillRect(amberPts[i][0], amberPts[i][1], amberPts[i][2], amberPts[i][2]);
          ctx.globalAlpha = 1;
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