import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    clip: false
    property var appData
    property var contextMenu: null
    property var dockApps: null
    property int index: -1
    property bool longPressing: false
    property bool dragging: false
    property point dragStartPos: Qt.point(0, 0)
    property point dragOffset: Qt.point(0, 0)
    property int targetIndex: -1
    property int originalIndex: -1
    property bool showWindowTitle: false
    property string windowTitle: ""
    property bool isHovered: mouseArea.containsMouse && !dragging
    property bool showTooltip: mouseArea.containsMouse && !dragging
    property bool isWindowFocused: {
        if (!appData || appData.type !== "window") {
            return false
        }
        var toplevel = getToplevelObject()
        if (!toplevel) {
            return false
        }
        return toplevel.activated
    }
    property string tooltipText: {
        if (!appData)
            return ""

        // For window type, show app name + window title
        if (appData.type === "window" && showWindowTitle) {
            var desktopEntry = DesktopEntries.byId(appData.appId)
            var appName = desktopEntry
                    && desktopEntry.name ? desktopEntry.name : appData.appId
            return appName + (windowTitle ? " • " + windowTitle : "")
        }
        // For pinned apps, just show app name
        if (!appData.appId)
            return ""

        var desktopEntry = DesktopEntries.byId(appData.appId)
        return desktopEntry
                && desktopEntry.name ? desktopEntry.name : appData.appId
    }

    width: 40
    height: 40
    
    function getToplevelObject() {
        if (!appData || appData.type !== "window") {
            return null
        }
        
        var sortedToplevels = CompositorService.sortedToplevels
        if (!sortedToplevels) {
            return null
        }

        if (appData.uniqueId) {
            for (var i = 0; i < sortedToplevels.length; i++) {
                var toplevel = sortedToplevels[i]
                var checkId = toplevel.title + "|" + (toplevel.appId || "") + "|" + i
                if (checkId === appData.uniqueId) {
                    return toplevel
                }
            }
        }

        if (appData.windowId !== undefined && appData.windowId !== null && appData.windowId >= 0) {
            if (appData.windowId < sortedToplevels.length) {
                return sortedToplevels[appData.windowId]
            }
        }
        
        return null
    }
    onIsHoveredChanged: {
        if (isHovered) {
            exitAnimation.stop()
            if (!bounceAnimation.running)
                bounceAnimation.restart()
        } else {
            bounceAnimation.stop()
            exitAnimation.restart()
        }
    }

    SequentialAnimation {
        id: bounceAnimation

        running: false

        NumberAnimation {
            target: translateY
            property: "y"
            to: -10
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: translateY
            property: "y"
            to: -8
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    NumberAnimation {
        id: exitAnimation

        running: false
        target: translateY
        property: "y"
        to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
        border.width: 2
        border.color: Theme.primary
        visible: dragging
        z: -1
    }

    Timer {
        id: longPressTimer

        interval: 500
        repeat: false
        onTriggered: {
            if (appData && appData.isPinned)
                longPressing = true
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        anchors.bottomMargin: -20
        hoverEnabled: true
        cursorShape: longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
                       if (mouse.button === Qt.LeftButton && appData
                           && appData.isPinned) {
                           dragStartPos = Qt.point(mouse.x, mouse.y)
                           longPressTimer.start()
                       }
                   }
        onReleased: mouse => {
                        longPressTimer.stop()
                        if (longPressing) {
                            if (dragging && targetIndex >= 0
                                && targetIndex !== originalIndex && dockApps)
                            dockApps.movePinnedApp(originalIndex, targetIndex)

                            longPressing = false
                            dragging = false
                            dragOffset = Qt.point(0, 0)
                            targetIndex = -1
                            originalIndex = -1
                        }
                    }
        onPositionChanged: mouse => {
                               if (longPressing && !dragging) {
                                   var distance = Math.sqrt(
                                       Math.pow(mouse.x - dragStartPos.x,
                                                2) + Math.pow(
                                           mouse.y - dragStartPos.y, 2))
                                   if (distance > 5) {
                                       dragging = true
                                       targetIndex = index
                                       originalIndex = index
                                   }
                               }
                               if (dragging) {
                                   dragOffset = Qt.point(
                                       mouse.x - dragStartPos.x,
                                       mouse.y - dragStartPos.y)
                                   if (dockApps) {
                                       var threshold = 40
                                       var newTargetIndex = targetIndex
                                       if (dragOffset.x > threshold
                                           && targetIndex < dockApps.pinnedAppCount - 1)
                                       newTargetIndex = targetIndex + 1
                                       else if (dragOffset.x < -threshold
                                                && targetIndex > 0)
                                       newTargetIndex = targetIndex - 1
                                       if (newTargetIndex !== targetIndex) {
                                           targetIndex = newTargetIndex
                                           dragStartPos = Qt.point(mouse.x,
                                                                   mouse.y)
                                       }
                                   }
                               }
                           }
        onClicked: mouse => {
                       if (!appData || longPressing)
                       return

                       if (mouse.button === Qt.LeftButton) {
                           // Handle based on type
                           if (appData.type === "pinned") {
                               // Launch the pinned app
                               if (appData && appData.appId) {
                                   var desktopEntry = DesktopEntries.byId(
                                       appData.appId)
                                   if (desktopEntry)
                                   AppUsageHistoryData.addAppUsage({
                                                                       "id": appData.appId,
                                                                       "name": desktopEntry.name
                                                                               || appData.appId,
                                                                       "icon": desktopEntry.icon
                                                                               || "",
                                                                       "exec": desktopEntry.exec
                                                                               || "",
                                                                       "comment": desktopEntry.comment || ""
                                                                   })

                                   desktopEntry.execute()
                               }
                           } else if (appData.type === "window") {
                               var toplevel = getToplevelObject()
                               if (toplevel) {
                                   toplevel.activate()
                               }
                           }
                       } else if (mouse.button === Qt.MiddleButton) {
                           if (appData && appData.appId) {
                               var desktopEntry = DesktopEntries.byId(
                                   appData.appId)
                               if (desktopEntry)
                               AppUsageHistoryData.addAppUsage({
                                                                   "id": appData.appId,
                                                                   "name": desktopEntry.name
                                                                           || appData.appId,
                                                                   "icon": desktopEntry.icon
                                                                           || "",
                                                                   "exec": desktopEntry.exec
                                                                           || "",
                                                                   "comment": desktopEntry.comment
                                                                              || ""
                                                               })

                                 desktopEntry.execute()
                           }
                       } else if (mouse.button === Qt.RightButton) {
                           if (contextMenu)
                           contextMenu.showForButton(root, appData, 40)
                       }
                   }
    }

    IconImage {
        id: iconImg

        anchors.centerIn: parent
        implicitSize: 40
        source: {
            if (!appData || !appData.appId)
                return ""

            var desktopEntry = DesktopEntries.byId(appData.appId)
            if (desktopEntry && desktopEntry.icon) {
                var iconPath = Quickshell.iconPath(
                            desktopEntry.icon, SettingsData.iconTheme
                            === "System Default" ? "" : SettingsData.iconTheme)
                return iconPath
            }
            return ""
        }
        mipmap: true
        smooth: true
        asynchronous: true
        visible: status === Image.Ready
    }

    Rectangle {
        width: 40
        height: 40
        anchors.centerIn: parent
        visible: iconImg.status !== Image.Ready
        color: Theme.surfaceLight
        radius: Theme.cornerRadius
        border.width: 1
        border.color: Theme.primarySelected

        Text {
            anchors.centerIn: parent
            text: {
                if (!appData || !appData.appId)
                    return "?"

                var desktopEntry = DesktopEntries.byId(appData.appId)
                if (desktopEntry && desktopEntry.name)
                    return desktopEntry.name.charAt(0).toUpperCase()

                return appData.appId.charAt(0).toUpperCase()
            }
            font.pixelSize: 14
            color: Theme.primary
            font.weight: Font.Bold
        }
    }

    // Indicator for running/focused state
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        width: 8
        height: 2
        radius: 1
        visible: appData && (appData.isRunning || appData.type === "window")
        color: {
            if (!appData)
                return "transparent"

            // For window type, check if focused using reactive property
            if (isWindowFocused)
                return Theme.primary

            // For running apps, show dimmer indicator
            if (appData.isRunning || appData.type === "window")
                return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.6)

            return "transparent"
        }
    }

    transform: Translate {
        id: translateY

        y: 0
    }
}
