import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var keyboardController: null
    property bool showSettings: false

    width: parent.width
    height: 32

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        StyledText {
            text: "Notifications"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        DankActionButton {
            id: doNotDisturbButton

            iconName: SessionData.doNotDisturb ? "notifications_off" : "notifications"
            iconColor: SessionData.doNotDisturb ? Theme.error : Theme.surfaceText
            buttonSize: 28
            anchors.verticalCenter: parent.verticalCenter
            onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)

            Rectangle {
                id: doNotDisturbTooltip

                width: tooltipText.contentWidth + Theme.spacingS * 2
                height: tooltipText.contentHeight + Theme.spacingXS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                border.color: Theme.outline
                border.width: 1
                anchors.bottom: parent.top
                anchors.bottomMargin: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                visible: doNotDisturbButton.children[1].containsMouse // Access StateLayer's containsMouse
                opacity: visible ? 1 : 0

                StyledText {
                    id: tooltipText

                    text: "Do Not Disturb"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.centerIn: parent
                    font.hintingPreference: Font.PreferFullHinting
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        // Keyboard help button
        DankActionButton {
            id: helpButton
            iconName: "info"
            iconColor: keyboardController
                       && keyboardController.showKeyboardHints ? Theme.primary : Theme.surfaceText
            buttonSize: 28
            visible: keyboardController !== null
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                if (keyboardController) {
                    keyboardController.showKeyboardHints = !keyboardController.showKeyboardHints
                }
            }
        }

        // Settings button
        DankActionButton {
            id: settingsButton
            iconName: "settings"
            iconColor: root.showSettings ? Theme.primary : Theme.surfaceText
            buttonSize: 28
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.showSettings = !root.showSettings
        }

        Rectangle {
            id: clearAllButton

            width: 120
            height: 28
            radius: Theme.cornerRadius
            visible: NotificationService.notifications.length > 0
            color: clearArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                     Theme.primary.g,
                                                     Theme.primary.b,
                                                     0.12) : Qt.rgba(
                                                 Theme.surfaceVariant.r,
                                                 Theme.surfaceVariant.g,
                                                 Theme.surfaceVariant.b, 0.3)
            border.color: clearArea.containsMouse ? Theme.primary : Qt.rgba(
                                                        Theme.outline.r,
                                                        Theme.outline.g,
                                                        Theme.outline.b, 0.08)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "delete_sweep"
                    size: Theme.iconSizeSmall
                    color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Clear All"
                    font.pixelSize: Theme.fontSizeSmall
                    color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: clearArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.clearAllNotifications()
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
}
