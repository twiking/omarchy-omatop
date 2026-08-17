import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omatop — CPU and memory in one bar widget: both values in the bar, and a
// popup that lists the top processes for each, the way `top` shows them
// together rather than as two separate readouts.
Panel {
  id: root
  moduleName: "io.github.twiking.omatop"
  ipcTarget: "omatop"

  readonly property int processCount: Math.max(1, Math.min(20, setting("processCount", 7)))
  readonly property int refreshIntervalSec: Math.max(1, Math.min(60, setting("refreshIntervalSec", 3)))
  readonly property bool showLabel: setting("showLabel", true) === true

  readonly property string statsPath: String(Qt.resolvedUrl("bin/omatop-stats")).replace(/^file:\/\//, "")

  property var cpu: Model.emptyStats()
  property var mem: Model.emptyStats()

  // The button paints meters and values, so the open-panel mark takes the
  // painted extent of that content instead of the default fraction of the slot,
  // which would stop short of it.
  readonly property real openPanelIndicatorWidth: button.vertical ? 0 : Math.ceil(barContent.implicitWidth)
  readonly property real openPanelIndicatorHeight: button.vertical ? Math.ceil(barContent.implicitHeight) : 0

  // Docker blue, fixed rather than themed — same tag color the Waybar modules
  // used, so a container row reads as a container row under any theme.
  readonly property color dockerColor: "#50a0e0"

  // Both metrics are sampled on every tick: the bar shows both values, and the
  // popup then opens on data that is already current.
  function refresh() {
    if (!cpuProc.running) {
      cpuProc.command = ["bash", root.statsPath, "cpu", String(root.processCount)]
      cpuProc.running = true
    }
    if (!memProc.running) {
      memProc.command = ["bash", root.statsPath, "memory", String(root.processCount)]
      memProc.running = true
    }
  }

  function apply(raw, metric) {
    var parsed = Model.parseStats(raw)
    // A transient empty read (fork failure, process churn) must not blank the
    // bar — keep the last good sample instead.
    if (parsed.text === "") return
    if (metric === "memory") mem = parsed
    else cpu = parsed
  }

  Process {
    id: cpuProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text, "cpu")
    }
  }

  Process {
    id: memProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text, "memory")
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

  // The bar button paints its own level meters rather than a glyph, so it uses
  // WidgetButton directly (BarIconButton is glyph-shaped) with the label off.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : Math.ceil(barContent.implicitWidth) + Style.space(12)
    fixedHeight: vertical ? Math.ceil(barContent.implicitHeight) + Style.space(8) : -1
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("omarchy-launch-or-focus-tui btop")
      else root.toggle()
    }

    // Horizontal bars label each meter with its name turned on its side;
    // vertical bars have no room for that, so they stack the bare meters and
    // let the popup carry the detail.
    Grid {
      id: barContent
      anchors.centerIn: parent
      columns: button.vertical ? 1 : 2
      rows: button.vertical ? 2 : 1
      flow: Grid.LeftToRight
      rowSpacing: Style.space(4)
      columnSpacing: Style.space(8)

      MeterGroup {
        label: "CPU"
        fraction: Model.fraction(root.cpu.total)
      }

      MeterGroup {
        label: "MEM"
        fraction: Model.fraction(root.mem.total)
      }
    }
  }

  // One metric in the bar: its name on its side, then its meter.
  component MeterGroup: Row {
    property string label: ""
    property real fraction: 0

    spacing: Style.space(3)

    MeterLabel { text: parent.label }

    LevelMeter { fraction: parent.fraction }
  }

  // A meter's name, rotated to read bottom-to-top so three characters fit in
  // the bar's height. Hidden on vertical bars, where there is no room for it.
  component MeterLabel: Item {
    id: meterLabel

    property string text: ""

    visible: !button.vertical && root.showLabel
    implicitWidth: visible ? Math.ceil(labelText.implicitHeight) : 0
    implicitHeight: visible ? Math.ceil(labelText.implicitWidth) : 0

    Text {
      id: labelText
      anchors.centerIn: parent
      text: meterLabel.text
      rotation: -90
      color: root.bar ? root.bar.barForeground : Color.foreground
      opacity: 0.7
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.5
      renderType: Text.NativeRendering
    }
  }

  // A single level bar: fills bottom-up on a horizontal bar, left-to-right on a
  // vertical one, and turns urgent once the resource is nearly exhausted.
  component LevelMeter: Item {
    id: meter

    property real fraction: 0
    readonly property bool horizontalFill: button.vertical
    readonly property color fillColor: fraction >= 0.9
      ? (root.bar ? root.bar.urgent : Color.urgent)
      : (root.bar ? root.bar.barForeground : Color.foreground)

    implicitWidth: horizontalFill ? Math.max(Style.space(16), button.barSize - Style.space(12)) : Style.space(6)
    implicitHeight: horizontalFill ? Style.space(6) : Style.space(16)

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: Math.min(width, height) / 2
      color: Qt.rgba(meter.fillColor.r, meter.fillColor.g, meter.fillColor.b, 0.22)
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.bottom: meterTrack.bottom
      width: meter.horizontalFill
        ? Math.max(meterTrack.height, meterTrack.width * meter.fraction)
        : meterTrack.width
      height: meter.horizontalFill
        ? meterTrack.height
        : Math.max(meterTrack.width, meterTrack.height * meter.fraction)
      radius: meterTrack.radius
      color: meter.fillColor

      Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 200 } }
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
        spacing: Style.space(16)

        MetricSection {
          width: parent.width
          metric: "cpu"
          stats: root.cpu
        }

        PanelSeparator { foreground: root.bar.foreground }

        MetricSection {
          width: parent.width
          metric: "memory"
          stats: root.mem
        }
      }
    }
  }

  // One metric's block: hero line, usage bar, its top processes, and the
  // metric's footer (load average for CPU, swap for memory).
  component MetricSection: Column {
    id: section

    property string metric: "cpu"
    property var stats: Model.emptyStats()

    readonly property real fraction: Model.fraction(stats.total)
    // Sized to the widest value in this section, so its rows sit flush against
    // the panel's left edge whatever the values are.
    readonly property real valueColumnWidth: Math.ceil(valueMetrics.advanceWidth)
    readonly property real containerIndent: valueColumnWidth + Style.space(10)

    spacing: Style.space(12)

    TextMetrics {
      id: valueMetrics
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.bodySmall
      text: Model.longestValue(section.stats.procs)
    }

    // ---------- Hero: icon · title · current value ----------
    Item {
      width: parent.width
      implicitHeight: Math.max(heroIcon.implicitHeight, heroTitle.implicitHeight, heroValue.implicitHeight)

      Text {
        id: heroIcon
        text: Model.metricIcon(section.metric)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.display
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: heroTitle
        text: Model.metricTitle(section.metric)
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
        text: section.stats.text === ""
          ? "—"
          : (section.stats.max !== "" ? section.stats.text + " / " + section.stats.max : section.stats.text)
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
        width: Math.max(track.height, track.width * section.fraction)

        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      }
    }

    // ---------- Top processes ----------
    Column {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: section.stats.procs

        Column {
          required property var modelData
          width: parent.width
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
              width: section.valueColumnWidth
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

          // Containerized process: name the container underneath, indented to
          // line up with the process name above it.
          Text {
            visible: modelData.container !== ""
            text: "└ " + modelData.container
            color: root.dockerColor
            opacity: 0.9
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width - section.containerIndent
            x: section.containerIndent
          }
        }
      }
    }

    // ---------- Footer: load average / swap ----------
    Row {
      width: parent.width
      visible: section.stats.detail !== ""
      spacing: Style.space(8)

      Text {
        text: section.stats.detailLabel
        color: root.bar.foreground
        opacity: 0.6
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        text: section.stats.detail
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
