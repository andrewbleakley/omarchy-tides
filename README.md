# Omarchy Tides

A bar widget for the [Omarchy](https://omarchy.org/) shell that shows the next
high or low tide, and a graph of today's tides.

Click the wave icon in the bar to open the panel:

- **Next tide** in large numbers: its time, and whether it's high or low, with its height in metres
- **Countdown** to the next tide, and the time and height of the tide after it
- **Today's tide graph**, midnight to midnight, with each high and low labelled and a marker at the current time

Right-click the icon to get the next tide as a desktop notification.

> [!IMPORTANT]
> **Only New South Wales, Australia, is supported for now.** Tides come from
> the NSW tide tables published by Transport for NSW and run from
> **1 July 2026 to 30 June 2027**. After that date the panel has no data until
> it's updated with the next year's tables.

## Install

You need Omarchy with the Omarchy shell (the Quickshell-based bar).

1. Clone the repository into your Omarchy plugins folder. The folder must be a
   real directory, not a symlink: the shell's hot reload doesn't follow symlinks.

   ```bash
   git clone https://github.com/andrewbleakley/omarchy-tides.git ~/.config/omarchy/plugins/local.tides
   ```

2. Add the widget to the bar, here next to the weather widget:

   ```bash
   omarchy bar put local.tides --after omarchy.weather
   ```

   Or choose a section yourself, for example `omarchy bar put local.tides --section right`.

3. If the widget doesn't appear, restart the shell:

   ```bash
   omarchy restart shell
   ```

### Update

```bash
git -C ~/.config/omarchy/plugins/local.tides pull
omarchy restart shell
```

### Uninstall

Remove the `local.tides` entry from `bar.layout` in `~/.config/omarchy/shell.json`,
then delete `~/.config/omarchy/plugins/local.tides`.

## Choosing a location

The default location is **Tweed Heads**. To change it, open the panel and
click the location name (or press <kbd>Enter</kbd>), then type to search about
100 NSW locations, from Tweed Heads to Eden, including river and lake
locations. Use <kbd>↑</kbd>/<kbd>↓</kbd> and <kbd>Enter</kbd> to choose one,
or <kbd>Esc</kbd> to cancel.

Your choice is saved to `~/.local/state/omarchy/settings/tides.json`:

```json
{
  "station": "Tweed Heads"
}
```

## Settings

| Setting     | Default | Description                          |
| ----------- | ------- | ------------------------------------ |
| `use24Hour` | `false` | Show times as 24-hour (`14:30`) instead of `2:30pm` |

## How it works

All predictions are for **Sydney (Fort Denison)**. Each location adds its own
time lag after Fort Denison, with separate lags for high and low water. The lags
come from the "Time variations – NSW ports and rivers" pages of the tide tables.
Tweed Heads isn't in those pages and uses a local lag of 4 minutes.

Things to know:

- **Heights are Fort Denison heights.** The tables only adjust times for each
  location, not heights, so heights elsewhere are approximate.
- **Times follow your computer's clock.** The tables use Sydney time, including
  daylight saving. The plugin stores each tide as an absolute time and shows it
  in your system's time zone, so it's correct whether your machine is set to
  NSW or Queensland time.
- **Between high and low water** the graph uses cosine interpolation, the usual
  approximation. It ignores weather, which can move real water levels.

These are predictions only. **Don't rely on them for navigation or
safety-critical decisions.**

## Updating the tide data

Transport for NSW publishes new tables each year. To regenerate `TideData.js`
from a new PDF (needs `pdftotext` from poppler and Python 3.9+):

```bash
python3 scripts/extract-tides.py support/tide-tables-YYYY-YYYY-for-nsw.pdf > TideData.js
```

The script reads the Fort Denison tables, converts Sydney local times to UTC,
labels each tide as high or low, and warns about anything that doesn't
alternate high/low.

## Files

| File                       | Purpose                                              |
| -------------------------- | ---------------------------------------------------- |
| `manifest.json`            | Plugin manifest                                      |
| `BarWidget.qml`            | Bar icon; loads the panel                            |
| `Panel.qml`                | Panel: next tide, countdown, location picker         |
| `TideGraph.qml`            | Daily tide graph                                     |
| `Model.js`                 | Tide calculations (no QML; can be run with Node)     |
| `Stations.js`              | NSW locations and their time lags                    |
| `TideData.js`              | Generated Fort Denison tide data                     |
| `scripts/extract-tides.py` | Builds `TideData.js` from the PDF tables             |

## Credits

Tidal predictions © Commonwealth of Australia, Bureau of Meteorology, published
by Transport for NSW in *NSW Tides 2026–2027*. This project isn't affiliated
with or endorsed by the Bureau of Meteorology or Transport for NSW.

The plugin structure follows Omarchy's built-in weather plugin.
