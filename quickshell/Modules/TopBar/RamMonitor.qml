import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    width: ramContent.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = ramArea.containsMouse ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    Component.onCompleted: {
        DgopService.addRef(["memory"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["memory"])
    }

    MouseArea {
        id: ramArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                var globalPos = mapToGlobal(0, 0)
                var currentScreen = parentScreen || Screen
                var screenX = currentScreen.x || 0
                var relativeX = globalPos.x - screenX
                popupTarget.setTriggerPosition(
                            relativeX, barHeight + Theme.spacingXS,
                            width, section, currentScreen)
            }
            DgopService.setSortBy("memory")
            if (root.toggleProcessList)
                root.toggleProcessList()
        }
    }

    Row {
        id: ramContent
        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "developer_board"
            size: Theme.iconSize - 8
            color: {
                if (DgopService.memoryUsage > 90)
                    return Theme.tempDanger

                if (DgopService.memoryUsage > 75)
                    return Theme.tempWarning

                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (DgopService.memoryUsage === undefined
                        || DgopService.memoryUsage === null
                        || DgopService.memoryUsage === 0) {
                    return "--%"
                }
                return DgopService.memoryUsage.toFixed(0) + "%"
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
