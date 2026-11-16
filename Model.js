// Pure tide logic, kept free of QML so it can be checked with node.
// Events are [utcSeconds, heightMetres, isHigh] rows (see TideData.js);
// a station is { name, hw, lw } with lags in minutes after Fort Denison.

// tides.json holds {"station": "<name>"}. Missing or unknown → the default.
function parseStationFile(raw, stations, fallback) {
  try {
    var data = JSON.parse(String(raw || ""))
    var found = findStation(stations, data && data.station)
    if (found) return found
  } catch (e) {}
  return findStation(stations, fallback) || stations[0]
}

function findStation(stations, name) {
  var wanted = String(name || "").toLowerCase()
  for (var i = 0; i < stations.length; i++)
    if (stations[i].name.toLowerCase() === wanted) return stations[i]
  return null
}

function filterStations(stations, query) {
  var q = String(query || "").replace(/^\s+|\s+$/g, "").toLowerCase()
  if (q === "") return stations.slice()
  return stations.filter(function(s) {
    return s.name.toLowerCase().indexOf(q) !== -1 || String(s.region || "").toLowerCase().indexOf(q) !== -1
  })
}

// Station tide as { time: Date, height, high }.
function stationTide(event, station) {
  var lag = event[2] ? station.hw : station.lw
  return { time: new Date((event[0] + lag * 60) * 1000), height: event[1], high: event[2] === 1 }
}

// Station tides between two Dates, padded with one tide either side so a
// curve can be drawn across the whole window.
function tidesBetween(events, station, from, to) {
  var out = []
  var before = null
  for (var i = 0; i < events.length; i++) {
    var t = stationTide(events[i], station)
    if (t.time < from) { before = t; continue }
    if (before) { out.push(before); before = null }
    out.push(t)
    if (t.time > to) break
  }
  return out
}

function nextTide(events, station, now) {
  for (var i = 0; i < events.length; i++) {
    var t = stationTide(events[i], station)
    if (t.time > now) return t
  }
  return null
}

function tideAfter(events, station, tide) {
  return tide ? nextTide(events, station, tide.time) : null
}

// Height at a moment by cosine interpolation between the bracketing
// high/low waters — the usual approximation between tabled extremes.
function heightAt(tides, time) {
  var ms = time.getTime()
  for (var i = 0; i + 1 < tides.length; i++) {
    var a = tides[i], b = tides[i + 1]
    var ta = a.time.getTime(), tb = b.time.getTime()
    if (ms >= ta && ms <= tb) {
      var f = (ms - ta) / (tb - ta)
      return a.height + (b.height - a.height) * (1 - Math.cos(Math.PI * f)) / 2
    }
  }
  return null
}

// "2h 13m" / "45m" until a time.
function countdown(now, time) {
  var mins = Math.max(0, Math.round((time.getTime() - now.getTime()) / 60000))
  var h = Math.floor(mins / 60)
  var m = mins % 60
  return h > 0 ? h + "h " + m + "m" : m + "m"
}

function formatHeight(h) {
  return Number(h).toFixed(2) + " m"
}

// Day starts at local midnight; the next midnight is found by date, not +24h,
// so a DST change on the user's machine still gives the right span.
function dayBounds(now) {
  var start = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
  return { start: start, end: end }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStationFile: parseStationFile,
    findStation: findStation,
    filterStations: filterStations,
    stationTide: stationTide,
    tidesBetween: tidesBetween,
    nextTide: nextTide,
    tideAfter: tideAfter,
    heightAt: heightAt,
    countdown: countdown,
    formatHeight: formatHeight,
    dayBounds: dayBounds
  }
}
