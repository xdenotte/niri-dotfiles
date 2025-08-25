import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modules.Notifications.Center
import qs.Services
import qs.Widgets

DankModal {
    id: notificationModal

    width: 500
    height: 700
    visible: false
    onBackgroundClicked: hide()
    onDialogClosed: {
        notificationModalOpen = false
        modalKeyboardController.reset()
    }

    modalFocusScope.Keys.onPressed: function (event) {
        modalKeyboardController.handleKey(event)
    }

    NotificationKeyboardController {
        id: modalKeyboardController
        listView: null
        isOpen: notificationModal.notificationModalOpen
        onClose: function () {
            notificationModal.hide()
        }
    }

    property bool notificationModalOpen: false
    property var notificationListRef: null

    function show() {
        notificationModalOpen = true
        NotificationService.onOverlayOpen()
        open()
        modalKeyboardController.reset()

        if (modalKeyboardController && notificationListRef) {
            modalKeyboardController.listView = notificationListRef
            modalKeyboardController.rebuildFlatNavigation()
        }
    }

    function hide() {
        notificationModalOpen = false
        NotificationService.onOverlayClose()
        close()
        modalKeyboardController.reset()
    }

    function toggle() {
        if (shouldBeVisible)
            hide()
        else
            show()
    }

    IpcHandler {
        function open() {
            notificationModal.show()
            return "NOTIFICATION_MODAL_OPEN_SUCCESS"
        }

        function close() {
            notificationModal.hide()
            return "NOTIFICATION_MODAL_CLOSE_SUCCESS"
        }

        function toggle() {
            notificationModal.toggle()
            return "NOTIFICATION_MODAL_TOGGLE_SUCCESS"
        }

        target: "notifications"
    }

    property Component notificationContent: Component {
        Item {
            id: notificationKeyHandler

            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                NotificationHeader {
                    id: notificationHeader
                    keyboardController: modalKeyboardController
                }

                NotificationSettings {
                    id: notificationSettings
                    expanded: notificationHeader.showSettings
                }

                KeyboardNavigatedNotificationList {
                    id: notificationList

                    width: parent.width
                    height: parent.height - y
                    keyboardController: modalKeyboardController

                    Component.onCompleted: {
                        notificationModal.notificationListRef = notificationList
                        if (modalKeyboardController) {
                            modalKeyboardController.listView = notificationList
                            modalKeyboardController.rebuildFlatNavigation()
                        }
                    }
                }
            }

            NotificationKeyboardHints {
                id: keyboardHints
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                showHints: modalKeyboardController.showKeyboardHints
            }
        }
    }

    content: notificationContent
}
