pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // Workspace management
    property var workspaces: ({})
    property var allWorkspaces: []
    property int focusedWorkspaceIndex: 0
    property string focusedWorkspaceId: ""
    property var currentOutputWorkspaces: []
    property string currentOutput: ""

    // Output/Monitor management
    property var outputs: ({}) // Map of output name to output info with positions

    // Window management
    property var windows: []

    // Overview state
    property bool inOverview: false

    // Internal state (not exposed to external components)
    property string configValidationOutput: ""
    property bool hasInitialConnection: false


    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")

    function fetchOutputs() {
        if (CompositorService.isNiri) {
            outputsProcess.running = true
        }
    }

    Process {
        id: outputsProcess
        command: ["niri", "msg", "-j", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var outputsData = JSON.parse(text)
                    outputs = outputsData
                    console.log("NiriService: Loaded",
                                Object.keys(outputsData).length, "outputs")
                    // Re-sort windows with monitor positions
                    if (windows.length > 0) {
                        windows = sortWindowsByLayout(windows)
                    }
                } catch (e) {
                    console.warn("NiriService: Failed to parse outputs:", e)
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn(
                    "NiriService: Failed to fetch outputs, exit code:",
                    exitCode)
            }
        }
    }

    Socket {
        id: eventStreamSocket
        path: root.socketPath
        connected: CompositorService.isNiri

        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n')
            }
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line)
                    handleNiriEvent(event)
                } catch (e) {
                    console.warn("NiriService: Failed to parse event:", line, e)
                }
            }
        }
    }

    Socket {
        id: requestSocket
        path: root.socketPath
        connected: CompositorService.isNiri
    }

    function sortWindowsByLayout(windowList) {
        return [...windowList].sort((a, b) => {
                                        // Get workspace info for both windows
                                        var aWorkspace = workspaces[a.workspace_id]
                                        var bWorkspace = workspaces[b.workspace_id]

                                        if (aWorkspace && bWorkspace) {
                                            var aOutput = aWorkspace.output
                                            var bOutput = bWorkspace.output

                                            // 1. First, sort by monitor position (left to right, top to bottom)
                                            var aOutputInfo = outputs[aOutput]
                                            var bOutputInfo = outputs[bOutput]

                                            if (aOutputInfo && bOutputInfo
                                                && aOutputInfo.logical
                                                && bOutputInfo.logical) {
                                                // Sort by monitor X position (left to right)
                                                if (aOutputInfo.logical.x
                                                    !== bOutputInfo.logical.x) {
                                                    return aOutputInfo.logical.x
                                                    - bOutputInfo.logical.x
                                                }
                                                // If same X, sort by Y position (top to bottom)
                                                if (aOutputInfo.logical.y
                                                    !== bOutputInfo.logical.y) {
                                                    return aOutputInfo.logical.y
                                                    - bOutputInfo.logical.y
                                                }
                                            }

                                            // 2. If same monitor, sort by workspace index
                                            if (aOutput === bOutput
                                                && aWorkspace.idx !== bWorkspace.idx) {
                                                return aWorkspace.idx - bWorkspace.idx
                                            }
                                        }

                                        // 3. If same workspace, sort by actual position within workspace
                                        if (a.workspace_id === b.workspace_id
                                            && a.layout && b.layout) {

                                            // Use pos_in_scrolling_layout [x, y] coordinates
                                            if (a.layout.pos_in_scrolling_layout
                                                && b.layout.pos_in_scrolling_layout) {
                                                var aPos = a.layout.pos_in_scrolling_layout
                                                var bPos = b.layout.pos_in_scrolling_layout

                                                if (aPos.length > 1
                                                    && bPos.length > 1) {
                                                    // Sort by X (horizontal) position first
                                                    if (aPos[0] !== bPos[0]) {
                                                        return aPos[0] - bPos[0]
                                                    }
                                                    // Then sort by Y (vertical) position
                                                    if (aPos[1] !== bPos[1]) {
                                                        return aPos[1] - bPos[1]
                                                    }
                                                }
                                            }
                                        }

                                        // 4. Fallback to window ID for consistent ordering
                                        return a.id - b.id
                                    })
    }

    function handleNiriEvent(event) {
        if (event.WorkspacesChanged) {
            handleWorkspacesChanged(event.WorkspacesChanged)
        } else if (event.WorkspaceActivated) {
            handleWorkspaceActivated(event.WorkspaceActivated)
        } else if (event.WorkspaceActiveWindowChanged) {
            handleWorkspaceActiveWindowChanged(
                        event.WorkspaceActiveWindowChanged)
        } else if (event.WindowsChanged) {
            handleWindowsChanged(event.WindowsChanged)
        } else if (event.WindowClosed) {
            handleWindowClosed(event.WindowClosed)
        } else if (event.WindowOpenedOrChanged) {
            handleWindowOpenedOrChanged(event.WindowOpenedOrChanged)
        } else if (event.WindowLayoutsChanged) {
            handleWindowLayoutsChanged(event.WindowLayoutsChanged)
        } else if (event.OutputsChanged) {
            handleOutputsChanged(event.OutputsChanged)
        } else if (event.OverviewOpenedOrClosed) {
            handleOverviewChanged(event.OverviewOpenedOrClosed)
        } else if (event.ConfigLoaded) {
            handleConfigLoaded(event.ConfigLoaded)
        }
    }

    function handleWorkspacesChanged(data) {
        const workspaces = {}

        for (const ws of data.workspaces) {
            workspaces[ws.id] = ws
        }

        root.workspaces = workspaces
        allWorkspaces = [...data.workspaces].sort((a, b) => a.idx - b.idx)

        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.is_focused)
        if (focusedWorkspaceIndex >= 0) {
            var focusedWs = allWorkspaces[focusedWorkspaceIndex]
            focusedWorkspaceId = focusedWs.id
            currentOutput = focusedWs.output || ""
        } else {
            focusedWorkspaceIndex = 0
            focusedWorkspaceId = ""
        }

        updateCurrentOutputWorkspaces()
    }

    function handleWorkspaceActivated(data) {
        const ws = root.workspaces[data.id]
        if (!ws)
            return
        const output = ws.output

        for (const id in root.workspaces) {
            const workspace = root.workspaces[id]
            const got_activated = workspace.id === data.id

            if (workspace.output === output) {
                workspace.is_active = got_activated
            }

            if (data.focused) {
                workspace.is_focused = got_activated
            }
        }

        focusedWorkspaceId = data.id
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.id === data.id)

        if (focusedWorkspaceIndex >= 0) {
            currentOutput = allWorkspaces[focusedWorkspaceIndex].output || ""
        }

        allWorkspaces = Object.values(root.workspaces).sort(
                    (a, b) => a.idx - b.idx)

        updateCurrentOutputWorkspaces()
        workspacesChanged()
    }

    function handleWorkspaceActiveWindowChanged(data) {
        // Update the focused window when workspace's active window changes
        // This is crucial for handling floating window close scenarios
        if (data.active_window_id !== null
                && data.active_window_id !== undefined) {
            // Create new windows array with updated focus states to trigger property change
            let updatedWindows = []
            for (var i = 0; i < windows.length; i++) {
                let w = windows[i]
                let updatedWindow = {}
                for (let prop in w) {
                    updatedWindow[prop] = w[prop]
                }
                updatedWindow.is_focused = (w.id == data.active_window_id)
                updatedWindows.push(updatedWindow)
            }
            windows = updatedWindows
        } else {
            // No active window in this workspace
            // Create new windows array with cleared focus states for this workspace
            let updatedWindows = []
            for (var i = 0; i < windows.length; i++) {
                let w = windows[i]
                let updatedWindow = {}
                for (let prop in w) {
                    updatedWindow[prop] = w[prop]
                }
                updatedWindow.is_focused = w.workspace_id
                        == data.workspace_id ? false : w.is_focused
                updatedWindows.push(updatedWindow)
            }
            windows = updatedWindows
        }
    }

    function handleWindowsChanged(data) {
        windows = sortWindowsByLayout(data.windows)
    }

    function handleWindowClosed(data) {
        windows = windows.filter(w => w.id !== data.id)
    }

    function handleWindowOpenedOrChanged(data) {
        if (!data.window)
            return

        const window = data.window
        const existingIndex = windows.findIndex(w => w.id === window.id)

        if (existingIndex >= 0) {
            let updatedWindows = [...windows]
            updatedWindows[existingIndex] = window
            windows = sortWindowsByLayout(updatedWindows)
        } else {
            windows = sortWindowsByLayout([...windows, window])
        }

    }

    function handleWindowLayoutsChanged(data) {
        // Update layout positions for windows that have changed
        if (!data.changes)
            return

        let updatedWindows = [...windows]
        let hasChanges = false

        for (const change of data.changes) {
            const windowId = change[0]
            const layoutData = change[1]

            const windowIndex = updatedWindows.findIndex(w => w.id === windowId)
            if (windowIndex >= 0) {
                // Create a new object with updated layout
                var updatedWindow = {}
                for (var prop in updatedWindows[windowIndex]) {
                    updatedWindow[prop] = updatedWindows[windowIndex][prop]
                }
                updatedWindow.layout = layoutData
                updatedWindows[windowIndex] = updatedWindow
                hasChanges = true
            }
        }

        if (hasChanges) {
            windows = sortWindowsByLayout(updatedWindows)
            // Trigger update in dock and widgets
            windowsChanged()
        }
    }

    function handleOutputsChanged(data) {
        if (data.outputs) {
            outputs = data.outputs
            // Re-sort windows with new monitor positions
            windows = sortWindowsByLayout(windows)
        }
    }

    function handleOverviewChanged(data) {
        inOverview = data.is_open
    }

    function handleConfigLoaded(data) {
        if (data.failed) {
            validateProcess.running = true
        } else {
            configValidationOutput = ""
            if (ToastService.toastVisible
                    && ToastService.currentLevel === ToastService.levelError) {
                ToastService.hideToast()
            }
            if (hasInitialConnection) {
                ToastService.showInfo("niri: config reloaded")
            }
        }

        if (!hasInitialConnection) {
            hasInitialConnection = true
        }
    }

    Process {
        id: validateProcess
        command: ["niri", "validate"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                const lines = text.split('\n')
                const trimmedLines = lines.map(line => line.replace(/\s+$/,
                                                                    '')).filter(
                    line => line.length > 0)
                configValidationOutput = trimmedLines.join('\n').trim()
                if (hasInitialConnection) {
                    ToastService.showError("niri: failed to load config",
                                           configValidationOutput)
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                configValidationOutput = ""
            }
        }
    }

    function updateCurrentOutputWorkspaces() {
        if (!currentOutput) {
            currentOutputWorkspaces = allWorkspaces
            return
        }

        var outputWs = allWorkspaces.filter(w => w.output === currentOutput)
        currentOutputWorkspaces = outputWs
    }

    function send(request) {
        if (!CompositorService.isNiri || !requestSocket.connected)
            return false
        requestSocket.write(JSON.stringify(request) + "\n")
        return true
    }

    function switchToWorkspace(workspaceIndex) {
        return send({
                        "Action": {
                            "FocusWorkspace": {
                                "reference": {
                                    "Index": workspaceIndex
                                }
                            }
                        }
                    })
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(
                    w => w.idx + 1) // niri uses 0-based, UI shows 1-based
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0
                && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].idx + 1
        }
        return 1
    }



    function quit() {
        return send({
                        "Action": {
                            "Quit": {
                                "skip_confirmation": true
                            }
                        }
                    })
    }



    function sortToplevels(toplevels) {
        if (!toplevels || toplevels.length === 0 || !CompositorService.isNiri || windows.length === 0) {
            return [...toplevels]
        }
       
        // Create a map to match toplevels to niri windows
        // We'll match by appId and title since toplevels don't have numeric IDs
        var toplevelToNiriMap = {}
        
        for (var i = 0; i < toplevels.length; i++) {
            var toplevel = toplevels[i]
            if (!toplevel.appId) continue
            
            // Find matching niri window by appId and optionally title
            for (var j = 0; j < windows.length; j++) {
                var niriWindow = windows[j]
                
                // Match by appId
                if (niriWindow.app_id === toplevel.appId) {
                    // If title also matches or niri window has no title, use this match
                    if (!niriWindow.title || niriWindow.title === toplevel.title) {
                        toplevelToNiriMap[i] = {
                            niriIndex: j,
                            niriWindow: niriWindow
                        }
                        break
                    }
                    // If we found appId match but no title match yet, store as fallback
                    if (!(i in toplevelToNiriMap)) {
                        toplevelToNiriMap[i] = {
                            niriIndex: j,
                            niriWindow: niriWindow
                        }
                    }
                }
            }
        }
        
        // Sort toplevels using niri's ordering
        return [...toplevels].sort((a, b) => {
            var aIndex = toplevels.indexOf(a)
            var bIndex = toplevels.indexOf(b)
            
            var aNiri = toplevelToNiriMap[aIndex]
            var bNiri = toplevelToNiriMap[bIndex]
            
            // If both have niri data, use niri ordering
            if (aNiri && bNiri) {
                return aNiri.niriIndex - bNiri.niriIndex
            }
            
            // If only one has niri data, prioritize it
            if (aNiri && !bNiri) return -1
            if (!aNiri && bNiri) return 1
            
            // If neither has niri data, keep original toplevel order
            return 0
        })
    }

}
