import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "Stations.js" as Stations
import "TideData.js" as TideData

Panel {
  id: root
  moduleName: "local.tides"
  ipcTarget: "local.tides"
  manageIpc: false

  property var anchorItem: null

  // See weather/Panel.qml: the bar identifies panels by the widget in its slot.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function open() {
    root.controller.show()
    root.tick()
  }

  function openFromHotkey() { open() }

  function close() {
    if (root.editingStation) root.cancelEditingStation()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // ---- Station, persisted as {"station": name} next to weather.json.
  property var station: Model.findStation(Stations.stations, Stations.defaultStation)

  property FileView stationFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/tides.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.station = Model.parseStationFile(text(), Stations.stations, Stations.defaultStation)
    onLoadFailed: root.station = Model.parseStationFile("", Stations.stations, Stations.defaultStation)
  }

  function saveStation(s) {
    if (!s) return
    root.station = s
    stationFile.setText(JSON.stringify({ station: s.name }, null, 2) + "\n")
    cancelEditingStation()
  }

  // ---- Clock. Ticks each minute, and on open, so the countdown stays live.
  property date now: new Date()
  function tick() { now = new Date() }

  Timer {
    interval: 30 * 1000
    running: true
    repeat: true
    onTriggered: root.tick()
  }

  readonly property bool use24Hour: setting("use24Hour", false) === true

  readonly property var next: Model.nextTide(TideData.events, station, now)
  readonly property var following: Model.tideAfter(TideData.events, station, next)
  readonly property var day: Model.dayBounds(now)
  readonly property var dayTides: Model.tidesBetween(TideData.events, station, day.start, day.end)

  readonly property string label: "󰞍"  // nf-md-waves

  readonly property string statusLine: next
    ? (next.high ? "High" : "Low") + " tide " + formatTime(next.time) + " (" + Model.formatHeight(next.height) + ") at " + station.name
    : "No tide data for " + station.name

  function clockTime(t) {
    if (use24Hour) return Qt.formatTime(t, "HH:mm")
    var m = t.getMinutes()
    return ((t.getHours() % 12) || 12) + ":" + (m < 10 ? "0" : "") + m
  }

  function meridiem(t) {
    return use24Hour ? "" : (t.getHours() < 12 ? "am" : "pm")
  }

  function formatTime(t) {
    return clockTime(t) + meridiem(t)
  }

  // ---- Station picker: clicking the location swaps it for a filter field.
  property bool editingStation: false
  property int suggestionIndex: 0
  property string stationQuery: ""
  readonly property var stationSuggestions: Model.filterStations(Stations.stations, stationQuery).slice(0, 8)

  function stationInput() {
    return panel.loadedContent ? panel.loadedContent.stationField : null
  }

  function startEditingStation() {
    editingStation = true
    stationQuery = ""
    suggestionIndex = 0
    Qt.callLater(function() {
      var field = root.stationInput()
      if (!field) return
      field.text = ""
      field.forceActiveFocus()
    })
  }

  function cancelEditingStation() {
    editingStation = false
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  ShellIpc {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function edit(): void { root.openFromHotkey(); root.startEditingStation() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias stationField: stationField
      implicitHeight: tideColumn.implicitHeight
      anchors.fill: parent
      blocked: root.editingStation
      onReturnRequested: root.startEditingStation()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: tideColumn
        width: parent.width
        spacing: Style.space(14)

        // ---- Hero: next tide time and height, large; station and countdown on the right.
        Item {
          width: parent.width
          height: Math.max(heroLeft.height, heroRight.height)

          Column {
            id: heroLeft
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: root.next ? (root.next.high ? "NEXT HIGH" : "NEXT LOW") : "NO DATA"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.letterSpacing: 1
            }

            Row {
              spacing: Style.space(2)
              LayoutMirroring.enabled: false

              Text {
                id: timeBig
                textFormat: Text.PlainText
                text: root.next ? root.clockTime(root.next.time) : "—"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                // Hero read-out; deliberately oversized like weather's temperature.
                font.pixelSize: 56
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: root.next ? root.meridiem(root.next.time) : ""
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
                anchors.top: timeBig.top
                anchors.topMargin: Style.space(10)
              }
              Item { width: Style.space(14); height: 1 }
              Text {
                id: heightBig
                visible: !!root.next
                textFormat: Text.PlainText
                text: root.next ? Number(root.next.height).toFixed(2) : ""
                color: Commons.Color.accent
                font.family: root.bar.fontFamily
                font.pixelSize: 40
                font.bold: true
                anchors.baseline: timeBig.baseline
              }
              Text {
                visible: !!root.next
                textFormat: Text.PlainText
                text: "m"
                color: Commons.Color.accent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
                anchors.baseline: timeBig.baseline
              }
            }
          }

          Column {
            id: heroRight
            anchors.right: parent.right
            anchors.rightMargin: Style.space(20)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(12)

            Row {
              anchors.right: parent.right
              visible: !root.editingStation
              spacing: Style.space(6)

              TapHandler { onTapped: root.startEditingStation() }
              HoverHandler { cursorShape: Qt.PointingHandCursor }

              Text {
                text: ""  // nf-fa-map_marker
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                textFormat: Text.PlainText
                text: root.station.name.toUpperCase()
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            TextField {
              id: stationField
              visible: root.editingStation
              width: Style.space(190)
              placeholderText: "Search NSW stations"
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily

              onTextChanged: {
                root.stationQuery = text
                root.suggestionIndex = 0
              }

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.cancelEditingStation()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                  if (root.suggestionIndex < root.stationSuggestions.length - 1) root.suggestionIndex++
                  event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                  if (root.suggestionIndex > 0) root.suggestionIndex--
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  root.saveStation(root.stationSuggestions[root.suggestionIndex])
                  event.accepted = true
                }
              }
            }

            Column {
              visible: !!root.next
              spacing: Style.space(10)

              Column {
                spacing: Style.space(5)
                Text {
                  text: "IN"
                  textFormat: Text.PlainText
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }
                Text {
                  textFormat: Text.PlainText
                  text: root.next ? Model.countdown(root.now, root.next.time) : ""
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.title
                }
              }

              Column {
                visible: !!root.following
                spacing: Style.space(5)
                Text {
                  text: root.following ? (root.following.high ? "THEN HIGH" : "THEN LOW") : ""
                  textFormat: Text.PlainText
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }
                Text {
                  textFormat: Text.PlainText
                  text: root.following ? root.formatTime(root.following.time) + "  " + Model.formatHeight(root.following.height) : ""
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.title
                }
              }
            }
          }
        }

        // ---- Station suggestions while picking.
        Column {
          visible: root.editingStation && root.stationSuggestions.length > 0
          width: parent.width
          spacing: 0

          Repeater {
            model: root.editingStation ? root.stationSuggestions : []

            Rectangle {
              required property var modelData
              required property int index
              width: parent.width
              height: suggestionRow.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: index === root.suggestionIndex ? Style.hoverFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"

              Row {
                id: suggestionRow
                anchors.left: parent.left
                anchors.leftMargin: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  text: modelData.name
                  color: index === root.suggestionIndex ? Style.hoverStateColor(root.bar.foreground, Commons.Color.accent) : root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  textFormat: Text.PlainText
                  visible: text !== ""
                  text: modelData.region
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: root.suggestionIndex = index
                onClicked: root.saveStation(modelData)
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Style.spacing.hairline
          color: root.bar.foreground
          opacity: 0.12
        }

        // ---- Today's tide curve, midnight to midnight.
        TideGraph {
          width: parent.width
          height: Style.space(170)
          tides: root.dayTides
          dayStart: root.day.start
          dayEnd: root.day.end
          now: root.now
          foreground: root.bar.foreground
          accent: Commons.Color.accent
          fontFamily: root.bar.fontFamily
          formatTime: root.formatTime
          use24Hour: root.use24Hour
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: "Fort Denison heights · times adjusted for " + root.station.name
          color: Qt.darker(root.bar.foreground, 1.6)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
