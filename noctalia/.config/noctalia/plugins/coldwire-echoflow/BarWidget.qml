import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
  id: root

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property var pluginApi: null

  property bool daemonUp: false

  implicitWidth: pill.width
  implicitHeight: pill.height

  Process {
    id: checkProc
    // bracketed pattern so the sh -c wrapper's own cmdline never matches
    command: ["sh", "-c", "pgrep -f '[e]choflow daemon' >/dev/null && echo on || echo off"]
    stdout: StdioCollector {
      onStreamFinished: root.daemonUp = text.indexOf("on") === 0
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: checkProc.running = true
  }

  Process {
    id: toggleProc
    command: ["/home/m31/dotfiles/extras/echoflow-toggle"]
  }

  Timer {
    id: delayedCheck
    interval: 900
    onTriggered: checkProc.running = true
  }

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.daemonUp ? "microphone" : "microphone-off"
    customIconColor: root.daemonUp ? Color.mTertiary : Color.mOnSurfaceVariant
    text: ""
    forceClose: true
    tooltipText: root.daemonUp
                 ? "ECHOFLOW // ONLINE — click to unload (frees ~7.6G VRAM)"
                 : "ECHOFLOW // OFFLINE — click to start"
    onClicked: {
      toggleProc.running = true;
      delayedCheck.restart();
    }
  }
}
