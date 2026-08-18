# Omatop

An Omarchy bar widget that shows CPU, memory, and disk usage side by side and,
in its popup, which processes are actually eating the CPU and memory, and how
each mounted disk is filling up.

- **CPU, memory, and disk in one widget** — all three readouts in the bar, process lists and disk breakdown in one popup
- **Per-process breakdown** — the top consumers per metric, aggregated by process name
- **Multi-disk aware** — every mounted disk gets its own readout in the bar and its own section in the popup, not just the root filesystem
- **Docker-aware** — processes inside containers show the container name underneath
- **Smart process names** — resolves unhelpful names like `MainThread`, Nix wrappers, and generic interpreters to the real application

![The Omatop popup](preview.png)

This is the Omarchy-shell port of
[waybar-top-cpu-mem](https://github.com/twiking/waybar-top-cpu-mem).

## Requirements

- Omarchy with `omarchy-shell` (Quattro or newer)
- `bash`, `nproc`, `top`, `ps`, `free`, and `df` — the `coreutils` and `procps-ng`
  packages an Omarchy install already has
- A Nerd Font as the bar font, for the metric and chart glyphs (Omarchy's default)
- Optional: `docker` — container names appear only when the Docker CLI is present;
  without it that step is skipped

Omatop needs no elevated privileges: it reads `/proc`, `ps`, and (when present)
`docker ps` as your own user.

## Install

```bash
omarchy plugin add https://github.com/twiking/omarchy-omatop.git
omarchy plugin enable io.github.twiking.omatop
```

The widget lands in the bar's right section; move it with `omarchy bar move`.

## Update

```bash
omarchy plugin update io.github.twiking.omatop
```

## Remove

```bash
omarchy plugin disable io.github.twiking.omatop   # takes it off the bar
omarchy plugin remove io.github.twiking.omatop    # deletes the plugin checkout
```

Removal deletes `~/.config/omarchy/plugins/io.github.twiking.omatop/`. Omatop
writes nothing outside its own settings keys in the widget's `bar.layout` entry
in `~/.config/omarchy/shell.json`; `omarchy plugin disable` drops that entry, and
no other file is touched.

## Settings

The popup has a collapsed `OMATOP SETTINGS` section at the bottom — click the header to
expand it and change the refresh interval, the number of processes listed per
metric, or what the bar shows (`Usage` vs `Icon only`). Changes save
immediately.

With the values turned off the bar falls back to a single bar-chart glyph
(`nf-md-chart_bar`), so the widget stays visible and clickable.

There is no config file of Omatop's own: bar widgets are configured inline in
their `bar.layout` entry in `~/.config/omarchy/shell.json`, which the shell owns,
so the panel writes through the shell's `updateEntryInline` the same way the
first-party widgets do. Editing that entry by hand works just as well:

| Key | Type | Default | What it does |
|---|---|---|---|
| `processCount` | integer 1–20 | `7` | How many rows (processes, or disks) the popup lists per metric |
| `refreshIntervalSec` | integer 1–60 | `3` | How often stats are sampled |
| `showValues` | boolean | `true` | Show the `CPU` / `MEM` / `DISK` readouts; off shows the bar-chart icon instead |
| `diskShowAvailable` | boolean | `true` | Each disk section's hero value is space left; off shows space used instead (the other one moves to the footer) |

```json
{
  "bar": {
    "layout": {
      "right": [
        { "id": "io.github.twiking.omatop", "processCount": 7 }
      ]
    }
  }
}
```

## The bar readout

Each metric is a two-line caption: its name in small type (`CPU`, `MEM`, `DISK`, or
`DISK1`/`DISK2`/... on a machine with several disks) with
the current value under it, the two lines centered on each other and sized to fit
the bar's height. Vertical bars have no room for text, so they show the bar-chart
glyph instead and leave the numbers to the popup.

## Interactions

- **Left click** — open/close the popup
- **Right click** — launch or focus `btop`
- **Esc** — close the popup

## How it works

`bin/omatop-stats <cpu|memory|disk> [count]` collects one metric in a single shot and
prints line-based TSV; `Panel.qml` runs it once per metric on a timer and
`Model.js` parses the output. Running the script by hand is the fastest way to
debug a wrong-looking number.

### CPU

CPU usage is normalized across all cores to a 0–100% scale (matching tools like
btop). `top` in batch mode measures percentages and `ps` resolves process names;
the two are joined by PID.

### Memory

Memory is aggregated per process name using RSS from `ps`, so multiple instances
of the same program (browser tabs, workers) are summed into one row. The bar
label shows used memory in GB, the panel adds total RAM after it, and the usage
bar shows the percentage of that total.

### Disk

Disk usage comes from `df`, one row per mounted filesystem, so a machine with
several disks (or a second drive mounted alongside the root filesystem) gets a
row for each — virtual/pseudo mounts (`tmpfs`, `overlay`, `proc`, and the like)
are filtered out, `/boot` is filtered out too (a fixed-size firmware/kernel
slice, not capacity anyone is managing), and a device bind-mounted more than
once is only counted once. The root filesystem (`/`) always comes first, then every other real disk
largest first. With only one disk the bar shows a single `DISK` readout; with
several, each gets its own numbered readout (`DISK1`, `DISK2`, ...). The popup
mirrors this with one section per disk, named with its mount point, each with
its own usage bar. By default the hero value is space left, since that is the
number that tells you whether you are about to run out, with space used in
the footer; the `Disk sections lead with` setting swaps the two.

### Process name resolution

CPU and memory handle cases where the reported process name is unhelpful:

- `MainThread` (Python apps) — resolved from the command line
- `.foo-wrapped` / `.foo-wrap` (Nix wrappers) — resolved to the actual binary name
- Generic interpreters (`node`, `python`, `bash`, etc.) are skipped in favor of the actual script or app name

### Docker detection

Processes running inside Docker containers are detected via cgroup membership
(`/sys/fs/cgroup/system.slice/docker-*.scope`) and matched against
`docker ps`. The container name is shown below the process row.

Docker is entirely optional. With no `docker` binary the lookup is skipped; if
the binary is there but the daemon refuses the connection, the error is ignored;
and if the daemon hangs, the call gives up after two seconds. In every case the
readout is the same minus container names.

## Development

```bash
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.twiking.omatop"
qmllint -I "$OMARCHY_PATH/shell" Panel.qml
```

## License

MIT — see [LICENSE](LICENSE).
