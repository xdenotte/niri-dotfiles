pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool isElogind: false
    property bool inhibitorAvailable: true
    property bool idleInhibited: false
    property string inhibitReason: "Keep system awake"

    Component.onCompleted: {
        detectElogindProcess.running = true
    }

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -Fx elogind-daemon"]

        onExited: function (exitCode) {
            console.log("SessionService: Elogind detection exited with code", exitCode)
            isElogind = (exitCode === 0)
        }
    }

    function suspend() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"])
    }

    function reboot() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"])
    }

    function poweroff() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"])
    }

    // * Idle Inhibitor
    signal inhibitorChanged

    function enableIdleInhibit() {
        if (idleInhibited)
            return
        idleInhibited = true
        inhibitorChanged()
    }

    function disableIdleInhibit() {
        if (!idleInhibited)
            return
        idleInhibited = false
        inhibitorChanged()
    }

    function toggleIdleInhibit() {
        if (idleInhibited) {
            disableIdleInhibit()
        } else {
            enableIdleInhibit()
        }
    }

    function setInhibitReason(reason) {
        inhibitReason = reason

        if (idleInhibited) {
            const wasActive = idleInhibited
            idleInhibited = false

            Qt.callLater(() => {
                             if (wasActive)
                             idleInhibited = true
                         })
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited) {
                return ["true"]
            }

            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", "--why="
                    + inhibitReason, "--mode=block", "sleep", "infinity"]
        }

        running: idleInhibited

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0) {
                console.warn("SessionService: Inhibitor process crashed with exit code:",
                             exitCode)
                idleInhibited = false
                ToastService.showWarning("Idle inhibitor failed")
            }
        }
    }

    IpcHandler {
        function toggle(): string {
            root.toggleIdleInhibit()
            return root.idleInhibited ? "Idle inhibit enabled" : "Idle inhibit disabled"
        }

        function enable(): string {
            root.enableIdleInhibit()
            return "Idle inhibit enabled"
        }

        function disable(): string {
            root.disableIdleInhibit()
            return "Idle inhibit disabled"
        }

        function status(): string {
            return root.idleInhibited ? "Idle inhibit is enabled" : "Idle inhibit is disabled"
        }

        function reason(newReason: string): string {
            if (!newReason) {
                return "Current reason: " + root.inhibitReason
            }

            root.setInhibitReason(newReason)
            return "Inhibit reason set to: " + newReason
        }

        target: "inhibit"
    }
}
