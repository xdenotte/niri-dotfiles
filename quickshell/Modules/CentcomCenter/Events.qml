import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: events

    property date selectedDate: new Date()
    property var selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0
    property bool shouldShow: CalendarService && CalendarService.khalAvailable

    function updateSelectedDateEvents() {
        if (CalendarService && CalendarService.khalAvailable) {
            let events = CalendarService.getEventsForDate(selectedDate)
            selectedDateEvents = events
        } else {
            selectedDateEvents = []
        }
    }

    onSelectedDateEventsChanged: {
        eventsList.model = selectedDateEvents
    }
    width: parent.width
    height: shouldShow ? (hasEvents ? Math.min(
                                          300,
                                          80 + selectedDateEvents.length * 60) : 120) : 0
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                   Theme.surfaceVariant.b, 0.12)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                          Theme.outline.b, 0.08)
    border.width: 1
    visible: shouldShow
    layer.enabled: true
    Component.onCompleted: {
        updateSelectedDateEvents()
    }
    onSelectedDateChanged: {
        updateSelectedDateEvents()
    }

    Connections {
        function onEventsByDateChanged() {
            updateSelectedDateEvents()
        }

        function onKhalAvailableChanged() {
            updateSelectedDateEvents()
        }

        target: CalendarService
        enabled: CalendarService !== null
    }

    Row {
        id: headerRow

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingS

        DankIcon {
            name: "event"
            size: Theme.iconSize - 2
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: hasEvents ? (Qt.formatDate(selectedDate, "MMM d") + " • "
                               + (selectedDateEvents.length
                                  === 1 ? "1 event" : selectedDateEvents.length
                                          + " events")) : Qt.formatDate(
                                  selectedDate, "MMM d")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        visible: !hasEvents

        DankIcon {
            name: "event_busy"
            size: Theme.iconSize + 8
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                           Theme.surfaceText.b, 0.3)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: "No events"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                           Theme.surfaceText.b, 0.5)
            font.weight: Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    DankListView {
        id: eventsList

        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingL
        anchors.topMargin: Theme.spacingM
        visible: opacity > 0
        opacity: hasEvents ? 1 : 0
        clip: true
        spacing: Theme.spacingS
        boundsBehavior: Flickable.StopAtBounds

        // Qt 6.9+ scrolling: flickDeceleration/maximumFlickVelocity only affect touch now
        interactive: true
        flickDeceleration: 1500
        maximumFlickVelocity: 2000
        boundsMovement: Flickable.FollowBoundsBehavior
        pressDelay: 0
        flickableDirection: Flickable.VerticalFlick

        // Custom wheel handler for Qt 6.9+ responsive mouse wheel scrolling
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real momentum: 0
            onWheel: event => {
                         if (event.pixelDelta.y !== 0) {
                             // Touchpad with pixel delta
                             momentum = event.pixelDelta.y * 1.8
                         } else {
                             // Mouse wheel with angle delta
                             momentum = (event.angleDelta.y / 120)
                             * (60 * 2.5) // ~2.5 items per wheel step
                         }

                         let newY = parent.contentY - momentum
                         newY = Math.max(
                             0, Math.min(parent.contentHeight - parent.height,
                                         newY))
                         parent.contentY = newY
                         momentum *= 0.92 // Decay for smooth momentum
                         event.accepted = true
                     }
        }

        ScrollBar.vertical: ScrollBar {
            policy: eventsList.contentHeight
                    > eventsList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        delegate: Rectangle {
            width: eventsList.width
            height: eventContent.implicitHeight + Theme.spacingM
            radius: Theme.cornerRadius
            color: {
                if (modelData.url && eventMouseArea.containsMouse)
                    return Qt.rgba(Theme.primary.r, Theme.primary.g,
                                   Theme.primary.b, 0.12)
                else if (eventMouseArea.containsMouse)
                    return Qt.rgba(Theme.primary.r, Theme.primary.g,
                                   Theme.primary.b, 0.06)
                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.06)
            }
            border.color: {
                if (modelData.url && eventMouseArea.containsMouse)
                    return Qt.rgba(Theme.primary.r, Theme.primary.g,
                                   Theme.primary.b, 0.3)
                else if (eventMouseArea.containsMouse)
                    return Qt.rgba(Theme.primary.r, Theme.primary.g,
                                   Theme.primary.b, 0.15)
                return "transparent"
            }
            border.width: 1

            Rectangle {
                width: 4
                height: parent.height - 8
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: Theme.primary
                opacity: 0.8
            }

            Column {
                id: eventContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingL + 4
                anchors.rightMargin: Theme.spacingM
                spacing: 6

                StyledText {
                    width: parent.width
                    text: modelData.title
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                Item {
                    width: parent.width
                    height: Math.max(timeRow.height, locationRow.height)

                    Row {
                        id: timeRow

                        spacing: 4
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            name: "schedule"
                            size: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: {
                                if (modelData.allDay) {
                                    return "All day"
                                } else {
                                    let timeFormat = SettingsData.use24HourClock ? "H:mm" : "h:mm AP"
                                    let startTime = Qt.formatTime(
                                            modelData.start, timeFormat)
                                    if (modelData.start.toDateString(
                                                ) !== modelData.end.toDateString(
                                                ) || modelData.start.getTime(
                                                ) !== modelData.end.getTime())
                                        return startTime + " – " + Qt.formatTime(
                                                    modelData.end, timeFormat)

                                    return startTime
                                }
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: locationRow

                        spacing: 4
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.location !== ""

                        DankIcon {
                            name: "location_on"
                            size: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: modelData.location
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, 200)
                        }
                    }
                }
            }

            MouseArea {
                id: eventMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: modelData.url !== ""
                onClicked: {
                    if (modelData.url && modelData.url !== "") {
                        if (Qt.openUrlExternally(modelData.url) === false)
                            console.warn("Failed to open URL: " + modelData.url)
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }

    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 2
        shadowBlur: 0.25
        shadowColor: Qt.rgba(0, 0, 0, 0.1)
        shadowOpacity: 0.1
    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }
}
