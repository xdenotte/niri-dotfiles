import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modals.Common
import qs.Modules.AppDrawer
import qs.Services
import qs.Widgets

DankModal {
    id: spotlightModal

    property bool spotlightOpen: false
    property Component spotlightContent

    function show() {
        spotlightOpen = true
        open()
        if (contentLoader.item && contentLoader.item.appLauncher) {
            contentLoader.item.appLauncher.searchQuery = ""
        }

        Qt.callLater(() => {
                         if (contentLoader.item && contentLoader.item.searchField) {
                             contentLoader.item.searchField.forceActiveFocus()
                         }
                     })
    }

    function hide() {
        spotlightOpen = false
        close()
        if (contentLoader.item && contentLoader.item.appLauncher) {
            contentLoader.item.appLauncher.searchQuery = ""
            contentLoader.item.appLauncher.selectedIndex = 0
            contentLoader.item.appLauncher.setCategory("All")
        }
    }

    function toggle() {
        if (spotlightOpen) {
            hide()
        } else {
            show()
        }
    }

    shouldBeVisible: spotlightOpen
    width: 550
    height: 600
    backgroundColor: Theme.popupBackground()
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    onVisibleChanged: () => {
                          if (visible && !spotlightOpen) {
                              show()
                          }
                          if (visible && contentLoader.item) {
                              Qt.callLater(() => {
                                               if (contentLoader.item.searchField) {
                                                   contentLoader.item.searchField.forceActiveFocus()
                                               }
                                           })
                          }
                      }
    onBackgroundClicked: () => {
                             return hide()
                         }
    content: spotlightContent

    Connections {
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== spotlightModal && !allowStacking && spotlightOpen) {
                spotlightOpen = false
            }
        }

        target: ModalManager
    }

    IpcHandler {
        function open(): string  {
            spotlightModal.show()
            return "SPOTLIGHT_OPEN_SUCCESS"
        }

        function close(): string  {
            spotlightModal.hide()
            return "SPOTLIGHT_CLOSE_SUCCESS"
        }

        function toggle(): string  {
            spotlightModal.toggle()
            return "SPOTLIGHT_TOGGLE_SUCCESS"
        }

        target: "spotlight"
    }

    spotlightContent: Component {
        SpotlightContent {
            parentModal: spotlightModal
        }
    }
}
