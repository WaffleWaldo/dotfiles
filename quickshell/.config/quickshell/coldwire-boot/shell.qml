// Coldwire boot overlay — fullscreen init sequence played over the deck build.
// Launched by coldwire-deck --boot; exits when the deck touches the ready flag
// (or after a 25s failsafe). Run manually: qs -c coldwire-boot
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property color cInk: "#C8C8C8"
  readonly property color cDim: "#8A8A8A"
  readonly property color cFaint: "#333333"
  readonly property color cBright: "#F2F2F0"
  readonly property color cAmber: "#FFB000"
  readonly property string mono: "JetBrains Mono"
  readonly property string readyFlag: Quickshell.env("XDG_RUNTIME_DIR") + "/coldwire-deck-ready"

  property real elapsed: 0
  property bool leaving: false

  PanelWindow {
    id: win
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"

    Rectangle {
      id: stage
      anchors.fill: parent
      color: "#050505"
      opacity: 1

      Behavior on opacity {
        NumberAnimation {
          duration: 650
          easing.type: Easing.OutQuad
        }
      }
      onOpacityChanged: if (opacity === 0) Qt.quit()

      // ── heartbeat ──
      Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
          root.elapsed += 0.1;
          if (root.elapsed > 25 && !root.leaving)
            stage.leave();   // failsafe
        }
      }
      // poll the deck-ready flag
      Timer {
        interval: 400
        running: !root.leaving
        repeat: true
        onTriggered: flagCheck.running = true
      }
      Process {
        id: flagCheck
        command: ["sh", "-c", "test -f '" + root.readyFlag + "' && echo y || true"]
        stdout: StdioCollector {
          onStreamFinished: {
            if (text.indexOf("y") === 0 && root.elapsed >= 3.6)
              stage.leave();
          }
        }
      }
      function leave() {
        root.leaving = true;
        statusLine.text = "DECK READY";
        statusLine.color = root.cAmber;
        leaveDelay.start();
      }
      Timer {
        id: leaveDelay
        interval: 450
        onTriggered: stage.opacity = 0
      }

      // ── ambient dot terrain along the bottom ──
      Canvas {
        id: sea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.34
        property real t: 0
        Timer {
          interval: 50
          running: true
          repeat: true
          onTriggered: {
            sea.t += 0.04;
            sea.requestPaint();
          }
        }
        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          var w = width, h = height;
          var reveal = Math.min(root.elapsed / 2.2, 1);   // terrain fades in
          ctx.fillStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 1);
          for (var r = 0; r < 26; r++) {
            var z = r / 25;
            var ybase = Math.pow(z, 1.5) * h * 0.92;
            var spread = 0.62 + 0.45 * z;
            var glow = (0.16 + 0.55 * Math.pow(z, 0.9)) * reveal;
            var sz = z < 0.4 ? 1 : 2;
            for (var c = 0; c < 130; c++) {
              var x01 = c / 129;
              var swell = 0.5 * Math.sin(x01 * 7.3 + t * 0.8 + z * 3.1)
                        + 0.3 * Math.sin(x01 * 13.7 - t * 1.1 + z * 1.7);
              var sx = (x01 - 0.5) * spread * w * 1.3 + w / 2;
              var sy = ybase - (swell + 0.8) * (10 + 42 * z);
              ctx.globalAlpha = glow;
              ctx.fillRect(sx, sy, sz, sz);
            }
          }
          ctx.globalAlpha = 1;
        }
      }

      // ── rotating icosahedron, faint, center-right ──
      Canvas {
        id: icosa
        x: parent.width * 0.62
        y: parent.height * 0.16
        width: parent.width * 0.30
        height: parent.height * 0.46
        property real angle: 0
        Timer {
          interval: 66
          running: true
          repeat: true
          onTriggered: {
            icosa.angle += 0.012;
            icosa.requestPaint();
          }
        }
        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          var phi = (1 + Math.sqrt(5)) / 2;
          var verts = [[-1, phi, 0], [1, phi, 0], [-1, -phi, 0], [1, -phi, 0], [0, -1, phi], [0, 1, phi], [0, -1, -phi], [0, 1, -phi], [phi, 0, -1], [phi, 0, 1], [-phi, 0, -1], [-phi, 0, 1]];
          var edges = [[0, 1], [0, 5], [0, 7], [0, 10], [0, 11], [1, 5], [1, 7], [1, 8], [1, 9], [2, 3], [2, 4], [2, 6], [2, 10], [2, 11], [3, 4], [3, 6], [3, 8], [3, 9], [4, 5], [4, 9], [4, 11], [5, 9], [5, 11], [6, 7], [6, 8], [6, 10], [7, 8], [7, 10], [8, 9], [10, 11]];
          var cx = width / 2, cy = height / 2;
          var scale = Math.min(width, height) * 0.34;
          var ca = Math.cos(angle), sa = Math.sin(angle);
          var cb = Math.cos(angle * 0.7), sb = Math.sin(angle * 0.7);
          var reveal = Math.min(Math.max(root.elapsed - 0.5, 0) / 1.6, 1);
          var proj = [];
          for (var i = 0; i < verts.length; i++) {
            var x = verts[i][0], y = verts[i][1], z = verts[i][2];
            var x1 = x * ca + z * sa;
            var z1 = -x * sa + z * ca;
            var y1 = y * cb - z1 * sb;
            var z2 = y * sb + z1 * cb;
            var d = 1 / (1 + z2 * 0.12);
            proj.push([cx + x1 * scale * d / 1.6, cy + y1 * scale * d / 1.6, z2]);
          }
          var nEdges = Math.ceil(edges.length * reveal);   // edges draw in one by one
          for (var e = 0; e < nEdges; e++) {
            var a = proj[edges[e][0]], b = proj[edges[e][1]];
            var depth = (a[2] + b[2]) / 2;
            ctx.strokeStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, (0.14 + 0.30 * (1 - (depth + 2) / 4)));
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(a[0], a[1]);
            ctx.lineTo(b[0], b[1]);
            ctx.stroke();
          }
          ctx.fillStyle = Qt.rgba(root.cInk.r, root.cInk.g, root.cInk.b, 0.6 * reveal);
          for (var p = 0; p < proj.length; p++)
            ctx.fillRect(proj[p][0] - 1, proj[p][1] - 1, 2, 2);
        }
      }

      // ── title block ──
      Column {
        x: parent.width * 0.12
        y: parent.height * 0.22
        spacing: 14

        Text {
          id: title
          font.family: root.mono
          font.pixelSize: 54
          font.letterSpacing: 14
          color: root.cBright
          property string target: "COLDWIRE"
          property int revealed: 0
          text: ""
          Timer {
            interval: 55
            running: true
            repeat: true
            property string glyphs: "!<>-_\\/[]{}=+*^?#"
            onTriggered: {
              if (root.elapsed < 0.4)
                return;
              title.revealed++;
              if (title.revealed >= title.target.length + 4) {
                title.text = title.target;
                stop();
                return;
              }
              var out = title.target.substring(0, Math.min(title.revealed, title.target.length));
              for (var i = title.revealed; i < title.target.length; i++)
                out += glyphs[Math.floor(Math.random() * glyphs.length)];
              title.text = out;
            }
          }
        }

        Text {
          font.family: root.mono
          font.pixelSize: 12
          font.letterSpacing: 4
          color: root.cDim
          text: "USERSPACE // INIT SEQUENCE"
          opacity: root.elapsed > 1.0 ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 400 } }
        }
      }

      // ── boot log ──
      Column {
        id: bootLog
        x: parent.width * 0.12
        y: parent.height * 0.40
        spacing: 9

        Repeater {
          model: [
            { at: 1.2, txt: "PALETTE // MONO + AMBER + RED" },
            { at: 1.6, txt: "CHRONO // SYNC" },
            { at: 2.0, txt: "MESH_04 // AMBIENT ROTATION" },
            { at: 2.4, txt: "TELEMETRY // /proc TAP" },
            { at: 2.8, txt: "VAULT_MAP // GRAPH LAYOUT" },
            { at: 3.2, txt: "AUDIO_TAP // PIPEWIRE MONITOR" },
            { at: 3.6, txt: "DECK // COMPOSING COLUMNS" }
          ]
          delegate: Row {
            required property var modelData
            spacing: 10
            visible: root.elapsed >= modelData.at
            Text {
              font.family: root.mono
              font.pixelSize: 11
              color: root.cAmber
              text: "[ OK ]"
            }
            Text {
              font.family: root.mono
              font.pixelSize: 11
              font.letterSpacing: 1
              color: root.cInk
              text: parent.modelData.txt
            }
          }
        }
      }

      // ── status + progress hairline ──
      Text {
        id: statusLine
        x: parent.width * 0.12
        anchors.bottom: progressTrack.top
        anchors.bottomMargin: 12
        font.family: root.mono
        font.pixelSize: 10
        font.letterSpacing: 2
        color: root.cDim
        text: {
          if (root.leaving) return "DECK READY";
          if (root.elapsed < 1.2) return "LOADING MODULES";
          if (root.elapsed < 3.6) return "BRINGING PANELS ONLINE";
          return "WAITING FOR DECK";
        }
      }
      Rectangle {
        id: progressTrack
        x: parent.width * 0.12
        width: parent.width * 0.30
        height: 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.16
        color: root.cFaint
        Rectangle {
          height: 1
          color: root.cAmber
          width: parent.width * Math.min(root.elapsed / 4.5, root.leaving ? 1 : 0.96)
          Behavior on width { NumberAnimation { duration: 300 } }
        }
      }

      // corner ticks
      Repeater {
        model: 4
        delegate: Item {
          id: tick
          readonly property bool onRight: index % 2 === 1
          readonly property bool onBottom: index > 1
          x: onRight ? stage.width - 26 : 18
          y: onBottom ? stage.height - 26 : 18
          Rectangle { width: 8; height: 1; color: root.cDim; y: tick.onBottom ? 7 : 0 }
          Rectangle { width: 1; height: 8; color: root.cDim; x: tick.onRight ? 7 : 0 }
        }
      }
    }
  }
}
