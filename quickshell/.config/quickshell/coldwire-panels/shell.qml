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
        property real velYaw: 0
        property real velPitch: 0
        property real accYaw: 0
        property real accPitch: 0
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
            if (net.orbiting) {
              // sample this tick's drag motion as the current fling velocity
              net.velYaw = Math.max(-0.12, Math.min(0.12, net.accYaw));
              net.velPitch = Math.max(-0.12, Math.min(0.12, net.accPitch));
              net.accYaw = 0;
              net.accPitch = 0;
            }
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

        FrameAnimation {
          id: coastAnim
          running: !net.orbiting && (Math.abs(net.velYaw) > 0.00015 || Math.abs(net.velPitch) > 0.00015)
          onTriggered: {
            // velocity/friction are tuned in 66ms-tick units; normalize to real frame time
            var k = frameTime / 0.066;
            net.yaw += net.velYaw * k;
            net.pitch = Math.max(-1.35, Math.min(1.35, net.pitch + net.velPitch * k));
            var f = Math.pow(0.94, k);
            net.velYaw *= f;
            net.velPitch *= f;
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
            // grabbing the map catches any ongoing spin
            net.velYaw = 0;
            net.velPitch = 0;
            net.accYaw = 0;
            net.accPitch = 0;
          }
          onPositionChanged: mouse => {
            net.idleTicks = 0;
            var dx = mouse.x - net.lastMx;
            var dy = mouse.y - net.lastMy;
            if (net.orbiting) {
              net.yaw += dx * 0.008;
              net.pitch = Math.max(-1.35, Math.min(1.35, net.pitch + dy * 0.008));
              net.accYaw += dx * 0.008;
              net.accPitch += dy * 0.008;
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

      Repeater {
        model: [
          { label: "BASS", fx: 0.18 },
          { label: "MID", fx: 0.50 },
          { label: "TRB", fx: 0.82 }
        ]
        delegate: MicroLabel {
          required property var modelData
          x: parent.width * (0.5 + (modelData.fx - 0.5) * 1.10) - width / 2
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 6
          font.pixelSize: 8
          text: modelData.label
          opacity: 0.55
        }
      }

      Canvas {
        id: wave
        anchors.fill: parent
        anchors.topMargin: 30
        anchors.bottomMargin: 8
        renderStrategy: Canvas.Cooperative
        property real t: 0
        property var targetSpec: []
        property real targetLevel: 0
        property real tgBass: 0
        property real tgMid: 0
        property real tgTreble: 0
        property real bass: 0
        property real mid: 0
        property real treble: 0
        property real heave: 0
        property real lastSignal: 0
        property var ripples: []
        property real sinceBass: 99
        property real sinceMid: 99
        property real sinceTreble: 99
        property real frameAcc: 0
        readonly property bool live: lastSignal > 0
        readonly property int rows: 54
        readonly property int cols: 180

        // ── continuous spectral path: 24 control points weaving far-left → near-right ──
        readonly property int ctrlN: 24
        property var ctrl: []          // rendered envelopes
        property var tgCtrl: []        // targets from cava
        property var pathX: []         // plane x (0..1) per control point
        property var pathZ: []         // plane z (0..1) per control point

        Component.onCompleted: {
          var cx = [], cz = [], c0 = [], t0 = [];
          for (var k = 0; k < ctrlN; k++) {
            var u = k / (ctrlN - 1);
            cx.push(0.06 + 0.88 * u);
            cz.push(0.30 + 0.40 * u + 0.09 * Math.sin(u * 9.4));   // serpentine through the depth
            c0.push(0);
            t0.push(0);
          }
          pathX = cx;
          pathZ = cz;
          ctrl = c0;
          tgCtrl = t0;
        }

        Process {
          id: cavaProc
          command: ["cava", "-p", Quickshell.shellDir + "/cava_raw.conf"]
          running: true
          stdout: SplitParser {
            onRead: line => {
              var vals = line.split(";").filter(s => s.length).map(Number);
              if (!vals.length)
                return;
              var n = vals.length;
              if (wave.targetSpec.length !== n)
                wave.targetSpec = new Array(n).fill(0);
              var bassEnd = Math.max(2, Math.round(n * 0.125));
              var midEnd = Math.round(n * 0.62);
              var sb = 0, sm = 0, st = 0, sum = 0, mx = 0;
              for (var i = 0; i < n; i++) {
                var v = Math.min(vals[i], 100) / 100;
                wave.targetSpec[i] = v;
                var vv = v * v;
                sum += vv;
                if (i < bassEnd) sb += vv;
                else if (i < midEnd) sm += vv;
                else st += vv;
                if (vals[i] > mx)
                  mx = vals[i];
              }
              wave.tgBass = Math.min(Math.sqrt(sb / bassEnd) * 2.6, 1);
              wave.tgMid = Math.min(Math.sqrt(sm / (midEnd - bassEnd)) * 3.2, 1);
              wave.tgTreble = Math.min(Math.sqrt(st / (n - midEnd)) * 3.6, 1);
              wave.targetLevel = Math.min(Math.sqrt(sum / n) * 3.4, 1);
              // aggregate spectrum onto the control points (frequency → position)
              for (var k = 0; k < wave.ctrlN; k++) {
                var lo = Math.floor(k * n / wave.ctrlN);
                var hi = Math.max(lo + 1, Math.floor((k + 1) * n / wave.ctrlN));
                var s = 0;
                for (var j = lo; j < hi; j++)
                  s += wave.targetSpec[j] * wave.targetSpec[j];
                var u = k / (wave.ctrlN - 1);
                var boost = 2.6 + u * 1.0;                    // treble bins run quieter
                wave.tgCtrl[k] = Math.min(Math.sqrt(s / (hi - lo)) * boost, 1);
              }
              if (mx > 2)
                wave.lastSignal = 3.2;
            }
          }
        }

        function advance(dt) {
          t += dt * 0.9;
          if (lastSignal > 0 && targetLevel < 0.02)
            lastSignal = Math.max(0, lastSignal - dt);
          var up = 1 - Math.pow(1 - 0.60, dt / 0.016);
          var down = 1 - Math.pow(1 - 0.10, dt / 0.016);
          for (var k = 0; k < ctrl.length; k++) {
            var tg = tgCtrl[k];
            ctrl[k] += (tg - ctrl[k]) * (tg > ctrl[k] ? up : down);
          }
          var lUp = 1 - Math.pow(1 - 0.70, dt / 0.016);
          var lDown = 1 - Math.pow(1 - 0.06, dt / 0.016);
          var beatBass = tgBass - bass > 0.11;
          var beatMid = tgMid - mid > 0.12;
          var beatTreble = tgTreble - treble > 0.13;
          bass += (tgBass - bass) * (tgBass > bass ? lUp : lDown);
          mid += (tgMid - mid) * (tgMid > mid ? lUp : lDown);
          treble += (tgTreble - treble) * (tgTreble > treble ? lUp : lDown);
          var hUp = 1 - Math.pow(1 - 0.06, dt / 0.016);
          var hDown = 1 - Math.pow(1 - 0.015, dt / 0.016);
          heave += (bass - heave) * (bass > heave ? hUp : hDown);
          // onsets per zone, but each ring is born at the exact frequency that hit:
          // strongest-rising control point in the zone, character lerped by pitch
          sinceBass += dt;
          sinceMid += dt;
          sinceTreble += dt;
          if (live && ripples.length < 16) {
            spawnZone(0, Math.round(ctrlN * 0.33), beatBass, tgBass, 0.30, 0.14, 0.55, "b");
            spawnZone(Math.round(ctrlN * 0.33), Math.round(ctrlN * 0.70), beatMid, tgMid, 0.16, 0.11, 0.40, "m");
            spawnZone(Math.round(ctrlN * 0.70), ctrlN, beatTreble, tgTreble, 99, 0.08, 99, "t");
          }
          for (var q = ripples.length - 1; q >= 0; q--) {
            ripples[q].r += dt * ripples[q].spd;
            ripples[q].amp *= Math.pow(0.32, dt);
            if (ripples[q].amp < 0.04 || ripples[q].r > 1.6)
              ripples.splice(q, 1);
          }
        }

        function spawnZone(lo, hi, beat, zoneTg, sustainTh, beatGap, sustainGap, zone) {
          var since = zone === "b" ? sinceBass : (zone === "m" ? sinceMid : sinceTreble);
          var fire = (beat && since > beatGap) || (zoneTg > sustainTh && since > sustainGap);
          if (!fire)
            return;
          // origin: strongest-rising (or simply strongest) control point in zone
          var best = lo, bestV = -1;
          for (var k = lo; k < hi; k++) {
            var rise = tgCtrl[k] - ctrl[k] + tgCtrl[k] * 0.35;
            if (rise > bestV) {
              bestV = rise;
              best = k;
            }
          }
          var u = best / (ctrlN - 1);
          ripples.push({
            r: 0.02,
            amp: Math.min(zoneTg * (1.5 - u * 0.7), 1.2),
            spd: 0.30 + u * 0.32,
            wd: 0.040 - u * 0.026,
            ox: pathX[best],
            oz: pathZ[best]
          });
          if (zone === "b") sinceBass = 0;
          else if (zone === "m") sinceMid = 0;
          else sinceTreble = 0;
        }

        Timer {
          interval: 40
          running: !wave.live
          repeat: true
          onTriggered: {
            wave.advance(0.04);
            wave.requestPaint();
          }
        }

        FrameAnimation {
          running: wave.live
          onTriggered: {
            wave.frameAcc += frameTime;
            if (wave.frameAcc < 0.0155)
              return;
            wave.advance(wave.frameAcc);
            wave.frameAcc = 0;
            wave.requestPaint();
          }
        }

        property var img: null

        onPaint: {
          var ctx = getContext("2d");
          var W = Math.floor(width), H = Math.floor(height);
          if (W <= 0 || H <= 0)
            return;
          ctx.reset();
          var amberPts = [];
          ctx.fillStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 1);
          var horizon = H * 0.14;
          var hs = H / 795;                      // lift budget scales with panel height
          var rip = ripples;
          var nC = ctrl.length;
          var chop = 1 + treble * 2.4;
          var heaveLift = 1 + heave * 0.9;
          var cs = [];
          for (var k = 0; k < nC; k++)
            cs.push(Math.pow(ctrl[k], 0.8) * (1.05 - (k / (nC - 1)) * 0.55));
          var SIG = 0.085, REJ = SIG * 3, REJ2 = REJ * REJ;
          // swell trig decomposed: sin(fx*x + ft*t + fz*z) via per-col/per-row tables
          var FX = [7.3, 13.7, 23.0], FT = [0.8, -1.2, 1.8], FZ = [3.1, 1.7, -4.2];
          var WT = [0.5, 0.3, 0.2 * chop];
          var colS = [], colC = [];
          for (var wv = 0; wv < 3; wv++) {
            var sArr = new Float64Array(cols), cArr = new Float64Array(cols);
            for (var c = 0; c < cols; c++) {
              var a = FX[wv] * (c / (cols - 1)) + FT[wv] * t;
              sArr[c] = Math.sin(a);
              cArr[c] = Math.cos(a);
            }
            colS.push(sArr);
            colC.push(cArr);
          }
          var inkR = 200, inkG = 200, inkB = 200;   // #C8C8C8
          for (var r = 0; r < rows; r++) {
            var z = r / (rows - 1);
            var ybase = horizon + Math.pow(z, 1.5) * H * 0.82;
            var spread = 0.60 + 0.50 * z;
            var depthScale = 0.30 + 0.70 * z;
            var rowGlow = 0.20 + 0.70 * Math.pow(z, 0.9);
            var sz = z < 0.35 ? 1 : 2;
            // row trig
            var rs = [], rc = [];
            for (var wv = 0; wv < 3; wv++) {
              rs.push(Math.sin(FZ[wv] * z));
              rc.push(Math.cos(FZ[wv] * z));
            }
            // row-surviving control points
            var rowK = [];
            for (var k = 0; k < nC; k++) {
              if (cs[k] < 0.02)
                continue;
              var dzc = z - pathZ[k];
              var q2 = dzc * dzc;
              if (q2 < REJ2)
                rowK.push([pathX[k], q2, cs[k]]);
            }
            // row-surviving rings
            var rowR = [];
            for (var q = 0; q < rip.length; q++) {
              var rp = rip[q];
              var rdz = z - rp.oz;
              if (Math.abs(rdz) <= rp.r + rp.wd * 4)
                rowR.push([rp.ox, rdz * rdz, rp.r, rp.wd, rp.amp]);
            }
            var xBase = W / 2 - 0.5 * spread * W * 1.30;
            var xStep = spread * W * 1.30 / (cols - 1);
            for (var c = 0; c < cols; c++) {
              var x01 = c / (cols - 1);
              var swell = WT[0] * (colS[0][c] * rc[0] + colC[0][c] * rs[0])
                        + WT[1] * (colS[1][c] * rc[1] + colC[1][c] * rs[1])
                        + WT[2] * (colS[2][c] * rc[2] + colC[2][c] * rs[2]);
              var lift = (swell + 1) * 14 * hs * heaveLift;
              var ridge = 0;
              for (var k = 0; k < rowK.length; k++) {
                var dxw = (x01 - rowK[k][0]) * 1.9;
                if (dxw > REJ || dxw < -REJ)
                  continue;
                ridge += rowK[k][2] * Math.exp(-(dxw * dxw + rowK[k][1]) / (SIG * SIG * 2));
              }
              lift += ridge * 230 * hs;
              var ringSum = 0;
              for (var q = 0; q < rowR.length; q++) {
                var rg = rowR[q];
                var rdx = (x01 - rg[0]) * 1.9;
                if (Math.abs(rdx) - rg[2] > rg[3] * 4)
                  continue;
                var rd = Math.sqrt(rdx * rdx + rg[1]);
                var rr = rd - rg[2];
                ringSum += rg[4] * Math.cos(rr / rg[3] * 1.8) * Math.exp(-(rr * rr) / (rg[3] * rg[3] * 4));
              }
              lift += ringSum * 90 * hs;
              var sx = (xBase + c * xStep) | 0;
              var sy = (ybase - lift * depthScale) | 0;
              if (sx < 0 || sy < 0 || sx > W - 2 || sy > H - 2)
                continue;
              var energy = ridge + Math.abs(ringSum) * 0.8;
              var bright = Math.min(rowGlow * (0.32 + 0.30 * (swell * 0.5 + 0.5) + 1.4 * energy), 1);
              ctx.globalAlpha = bright;
              ctx.fillRect(sx, sy, sz, sz);
              if (energy > 0.55)
                amberPts.push([sx, sy - 2, sz]);
            }
          }
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