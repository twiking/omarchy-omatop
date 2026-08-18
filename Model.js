// Parsing helpers for the Omatop bar widget. Kept out of Panel.qml so the
// TSV contract with bin/omatop-stats lives in one place.

// Parse the TSV emitted by bin/omatop-stats into
// { total, text, max, detail, detailLabel, procs: [{ value, name, container }],
//   disks: [{ pct, text, max, avail, mount }] }.
// `disks` is only populated for the disk metric, one entry per mounted
// filesystem (root first), and drives the bar readout and popup instead of
// the single total/text/max/procs fields the other metrics use.
function emptyStats() {
  return { total: 0, text: "", max: "", detail: "", detailLabel: "", procs: [], disks: [] }
}

function parseStats(raw) {
  var result = emptyStats()
  var lines = String(raw || "").split("\n")

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line === "") continue
    var f = line.split("\t")
    switch (f[0]) {
    case "total":
      result.total = clampPercent(parseFloat(f[1]))
      break
    case "text":
      result.text = f[1] || ""
      break
    case "max":
      result.max = f[1] || ""
      break
    case "detail":
      result.detail = f[1] || ""
      break
    case "detailLabel":
      result.detailLabel = f[1] || ""
      break
    case "proc":
      if (f[2])
        result.procs.push({ value: f[1] || "", name: f[2], container: f[3] || "" })
      break
    case "disk":
      result.disks.push({
        pct: clampPercent(parseFloat(f[1])),
        text: f[2] || "",
        max: f[3] || "",
        avail: f[4] || "",
        mount: f[5] || ""
      })
      break
    }
  }

  return result
}

function clampPercent(value) {
  if (isNaN(value)) return 0
  return Math.max(0, Math.min(100, value))
}

// 0..1 fraction for the usage bar.
function fraction(percent) {
  return clampPercent(percent) / 100
}

// Widest value string in the list, used to size the value column so the rows
// start flush with the panel's left edge instead of inside a fixed gutter.
function longestValue(procs) {
  var widest = ""
  for (var i = 0; i < (procs ? procs.length : 0); i++) {
    if (procs[i].value.length > widest.length) widest = procs[i].value
  }
  return widest
}

function metricTitle(metric) {
  if (metric === "memory") return "Memory"
  if (metric === "disk") return "Disk"
  if (metric === "gpu") return "GPU"
  return "CPU"
}

// The widget's own glyph (nf-md-chart_bar), shown in place of the bar readouts
// when the values are off or the bar is vertical.
function widgetIcon() {
  return "󰄨"
}

// Nerd Font glyphs: microchip for CPU, memory sticks for RAM, hard disk for
// storage, graphics card for GPU.
function metricIcon(metric) {
  if (metric === "memory") return ""
  if (metric === "disk") return "󰋊"
  if (metric === "gpu") return "󰢮"
  return ""
}
