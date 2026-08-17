// Parsing helpers for the Omatop bar widget. Kept out of Panel.qml so the
// TSV contract with bin/omatop-stats lives in one place.

// Parse the TSV emitted by bin/omatop-stats into
// { total, text, max, detail, detailLabel, procs: [{ value, name, container }] }.
function emptyStats() {
  return { total: 0, text: "", max: "", detail: "", detailLabel: "", procs: [] }
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
  return metric === "memory" ? "Omatop Memory" : "Omatop CPU"
}

// Nerd Font glyphs: microchip for CPU, memory sticks for RAM.
function metricIcon(metric) {
  return metric === "memory" ? "" : ""
}
