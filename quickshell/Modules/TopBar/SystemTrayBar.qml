import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common

Rectangle {
    id: root

    property var parentWindow: null
    property var parentScreen: null
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS

    readonly property int calculatedWidth: SystemTray.items.values.length
                                           > 0 ? SystemTray.items.values.length
                                                 * 24 + horizontalPadding * 2 : 0

    width: calculatedWidth
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SystemTray.items.values.length === 0)
            return "transparent"
        
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    visible: SystemTray.items.values.length > 0

    Row {
        id: systemTrayRow

        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: SystemTray.items.values

            delegate: Item {
                property var trayItem: modelData
                property string iconSource: {
                    let icon = trayItem && trayItem.icon
                    if (typeof icon === 'string' || icon instanceof String) {
                        if (icon.includes("?path=")) {
                            const split = icon.split("?path=")
                            if (split.length !== 2)
                                return icon
                            const name = split[0]
                            const path = split[1]
                            const fileName = name.substring(
                                               name.lastIndexOf("/") + 1)
                            return `file://${path}/${fileName}`
                        }
                        return icon
                    }
                    return ""
                }

                width: 24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"

                    Behavior on color {
                        enabled: trayItemArea.containsMouse !== undefined

                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: parent.iconSource
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: trayItemArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                                   if (!trayItem)
                                   return

                                   if (mouse.button === Qt.LeftButton
                                       && !trayItem.onlyMenu) {
                                       trayItem.activate()
                                       return
                                   }

                                   if (trayItem.hasMenu) {
                                       var globalPos = mapToGlobal(0, 0)
                                       var currentScreen = parentScreen
                                       || Screen
                                       var screenX = currentScreen.x || 0
                                       var relativeX = globalPos.x - screenX
                                       menuAnchor.menu = trayItem.menu
                                       menuAnchor.anchor.window = parentWindow
                                       menuAnchor.anchor.rect = Qt.rect(
                                           relativeX,
                                           Theme.barHeight + Theme.spacingS,
                                           parent.width, 1)
                                       menuAnchor.open()
                                   }
                               }
                }
            }
        }
    }

    QsMenuAnchor {
        id: menuAnchor
    }
}
