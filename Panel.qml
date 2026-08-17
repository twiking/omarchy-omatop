import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omatop — CPU or memory usage in the bar, with a per-process breakdown in
// the popup. One widget instance covers one metric; add the widget twice
// (metric: "cpu" and metric: "memory") to get both, the way the original
// Waybar modules were configured.
Panel {
  id: root
  moduleName: "io.github.twiking.omatop"

  readonly property string metric: setting("metric", "cpu") === "memory" ? "memory" : "cpu"
  readonly property int processCount: Math.max(1, Math.min(20, setting("processCount", 10)))
  readonly property int refreshIntervalSec: Math.max(1, Math.min(60, setting("refreshIntervalSec", 3)))
  readonly property bool showLabel: setting("showLabel", true) === true

  // Widget can be placed twice, so the IPC target is per-metric rather than
  // per-plugin — two instances may not claim the same target.
  ipcTarget: "omatop-" + metric

  readonly property string statsPath: String(Qt.resolvedUrl("bin/omatop-stats")).replace(/^file:\/\//, "")

  property real total: 0
  property string label: ""
  property string detail: ""
  property string detailLabel: ""
  property var procs: []

  readonly property string title: Model.metricTitle(metric)
  readonly property string icon: Model.metricIcon(metric)
  readonly property real fraction: Model.fraction(total)

  // The bar label is polled continuously; the process list only matters while
  // the popup is up, but it rides along in the same call so opening the panel
  // shows data immediately instead of after the next tick.
  function refresh() {
    if (statsProc.running) return
    statsProc.command = ["bash", root.statsPath, root.metric, String(root.processCount)]
    statsProc.running = true
  }

  function apply(raw) {
    var parsed = Model.parseStats(raw)
    // A transient empty read (fork failure, process churn) must not blank the
    // bar — keep the last good sample instead.
    if (parsed.text === "") return
    total = parsed.total
    label = parsed.text
    detail = parsed.detail
    detailLabel = parsed.detailLabel
    procs = parsed.procs
  }

  Process {
    id: statsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (opened) refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  TextMetrics {
    id: labelMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.bar.iconFont
    text: button.text
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showLabel && !vertical && root.label !== ""
      ? root.label + " " + root.icon
      : root.icon
    // With the value shown the button paints a text block wider than an icon,
    // so the slot has to follow the measured text width or the label bleeds
    // into the next widget.
    slotSize: root.showLabel && !vertical
      ? Math.max(Style.bar.iconSlot, Math.ceil(labelMetrics.advanceWidth) + Style.space(12))
      : Style.bar.iconSlot
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("omarchy-launch-or-focus-tui btop")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: icon · title · current value ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroTitle.implicitHeight, heroValue.implicitHeight)

          Text {
            id: heroIcon
            text: root.icon
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: heroTitle
            text: root.title
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroValue.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: heroValue
            text: root.label !== "" ? root.label : "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Usage bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            height: track.height
            radius: track.radius
            color: root.bar.foreground
            width: Math.max(track.height, track.width * root.fraction)

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Top processes ----------
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "TOP PROCESSES"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Repeater {
            model: root.procs

            Column {
              required property var modelData
              width: column.width
              spacing: Style.space(2)

              Row {
                width: parent.width
                spacing: Style.space(10)

                Text {
                  id: procValue
                  text: modelData.value
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  horizontalAlignment: Text.AlignRight
                  width: Style.space(56)
                }

                Text {
                  text: modelData.name
                  color: root.bar.foreground
                  opacity: 0.85
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  width: parent.width - procValue.width - parent.spacing
                }
              }

              // Containerized process: name the container underneath, indented
              // to line up with the process name above it.
              Text {
                visible: modelData.container !== ""
                text: "└ " + modelData.container
                color: root.bar.foreground
                opacity: 0.5
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width - Style.space(66)
                x: Style.space(66)
              }
            }
          }
        }

        // ---------- Footer: load average / swap ----------
        Column {
          width: parent.width
          visible: root.detail !== ""
          spacing: Style.space(8)

          PanelSeparator { foreground: root.bar.foreground }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: root.detailLabel
              color: root.bar.foreground
              opacity: 0.6
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              text: root.detail
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
