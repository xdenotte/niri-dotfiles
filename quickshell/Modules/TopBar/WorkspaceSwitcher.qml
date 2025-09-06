import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string screenName: ""
    property real widgetHeight: 30
    property int currentWorkspace: {
        if (CompositorService.isNiri) {
            return getNiriActiveWorkspace()
        } else if (CompositorService.isHyprland) {
            return getHyprlandActiveWorkspace()
        }
        return 1
    }
    property var workspaceList: {
        if (CompositorService.isNiri) {
            const baseList = getNiriWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isHyprland) {
            const baseList = getHyprlandWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        return [1]
    }

    function getWorkspaceIcons(ws) {
        if (!SettingsData.showWorkspaceApps || !ws) {
            return []
        }

        let targetWorkspaceId
        if (CompositorService.isNiri) {
            const wsNumber = typeof ws === "number" ? ws : -1
            if (wsNumber <= 0) {
                return []
            }
            const workspace = NiriService.allWorkspaces.find(w => w.idx + 1 === wsNumber && w.output === root.screenName)
            if (!workspace) {
                return []
            }
            targetWorkspaceId = workspace.id
        } else if (CompositorService.isHyprland) {
            targetWorkspaceId = ws.id !== undefined ? ws.id : ws
        } else {
            return []
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels


        const byApp = {}
        const isActiveWs = CompositorService.isNiri ? NiriService.allWorkspaces.some(ws => ws.id === targetWorkspaceId && ws.is_active) : targetWorkspaceId === root.currentWorkspace

        wins.forEach((w, i) => {
                         if (!w) {
                             return
                         }

                         let winWs = null
                         if (CompositorService.isNiri) {
                             winWs = w.workspace_id
                         } else {
                             // For Hyprland, we need to find the corresponding Hyprland toplevel to get workspace
                             const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || [])
                             const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w)
                             winWs = hyprToplevel?.workspace?.id
                         }


                         if (winWs === undefined || winWs === null || winWs !== targetWorkspaceId) {
                             return
                         }

                         const keyBase = (w.appId || w.class || w.windowClass || "unknown").toLowerCase()
                         const key = isActiveWs ? `${keyBase}_${i}` : keyBase

                         if (!byApp[key]) {
                             const icon = Quickshell.iconPath(DesktopEntries.heuristicLookup(Paths.moddedAppId(keyBase))?.icon, true)
                             byApp[key] = {
                                 "type": "icon",
                                 "icon": icon,
                                 "active": !!(w.activated || (CompositorService.isNiri && w.is_focused)),
                                 "count": 1,
                                 "windowId": w.address || w.id,
                                 "fallbackText": w.appId || w.class || w.title || ""
                             }
                         } else {
                             byApp[key].count++
                             if (w.activated || (CompositorService.isNiri && w.is_focused)) {
                                 byApp[key].active = true
                             }
                         }
                     })

        return Object.values(byApp)
    }

    function padWorkspaces(list) {
        const padded = list.slice()
        const placeholder = CompositorService.isHyprland ? {
                                                               "id": -1,
                                                               "name": ""
                                                           } : -1
        while (padded.length < 3) {
            padded.push(placeholder)
        }
        return padded
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0) {
            return [1, 2]
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentOutputWorkspaceNumbers()
        }

        const displayWorkspaces = NiriService.allWorkspaces.filter(ws => ws.output === root.screenName).map(ws => ws.idx + 1)
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2]
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0) {
            return 1
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentWorkspaceNumber()
        }

        const activeWs = NiriService.allWorkspaces.find(ws => ws.output === root.screenName && ws.is_active)
        return activeWs ? activeWs.idx + 1 : 1
    }

    function getHyprlandWorkspaces() {
        const workspaces = Hyprland.workspaces?.values || []
        
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            // Show all workspaces on all monitors if per-monitor filtering is disabled
            const sorted = workspaces.slice().sort((a, b) => a.id - b.id)
            return sorted.length > 0 ? sorted : [{
                        "id": 1,
                        "name": "1"
                    }]
        }

        // Filter workspaces for this specific monitor using lastIpcObject.monitor
        // This matches the approach from the original kyle-config
        const monitorWorkspaces = workspaces.filter(ws => {
            return ws.lastIpcObject && ws.lastIpcObject.monitor === root.screenName
        })
        
        if (monitorWorkspaces.length === 0) {
            // Fallback if no workspaces exist for this monitor
            return [{
                        "id": 1,
                        "name": "1"
                    }]
        }

        // Return all workspaces for this monitor, sorted by ID
        return monitorWorkspaces.sort((a, b) => a.id - b.id)
    }

    function getHyprlandActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        }

        // Find the monitor object for this screen
        const monitors = Hyprland.monitors?.values || []
        const currentMonitor = monitors.find(monitor => monitor.name === root.screenName)
        
        if (!currentMonitor) {
            return 1
        }

        // Use the monitor's active workspace ID (like original config)
        return currentMonitor.activeWorkspace?.id ?? 1
    }

    readonly property real padding: (widgetHeight - workspaceRow.implicitHeight) / 2

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => {
                                             if (CompositorService.isHyprland) {
                                                 return ws && ws.id !== -1
                                             }
                                             return ws !== -1
                                         })
    }

    function switchWorkspace(direction) {
        if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? (validIndex + 1) % realWorkspaces.length : (validIndex - 1 + realWorkspaces.length) % realWorkspaces.length

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1)
        } else if (CompositorService.isHyprland) {
            const command = direction > 0 ? "workspace r+1" : "workspace r-1"
            Hyprland.dispatch(command)
        }
    }

    width: workspaceRow.implicitWidth + padding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground)
            return "transparent"
        const baseColor = Theme.surfaceTextHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        property real scrollAccumulator: 0
        property real touchpadThreshold: 500

        onWheel: wheel => {
                     const deltaY = wheel.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0
                     const direction = deltaY < 0 ? 1 : -1

                     if (isMouseWheel) {
                         switchWorkspace(direction)
                     } else {
                         scrollAccumulator += deltaY

                         if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                             const touchDirection = scrollAccumulator < 0 ? 1 : -1
                             switchWorkspace(touchDirection)
                             scrollAccumulator = 0
                         }
                     }

                     wheel.accepted = true
                 }
    }

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        Repeater {
            model: root.workspaceList

            Rectangle {
                property bool isActive: {
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === root.currentWorkspace
                    }
                    return modelData === root.currentWorkspace
                }
                property bool isPlaceholder: {
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === -1
                    }
                    return modelData === -1
                }
                property bool isHovered: mouseArea.containsMouse
                property var workspaceData: {
                    if (isPlaceholder) {
                        return null
                    }

                    if (CompositorService.isNiri) {
                        return NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null
                    }
                    return CompositorService.isHyprland ? modelData : null
                }
                property var iconData: workspaceData?.name ? SettingsData.getWorkspaceNameIcon(workspaceData.name) : null
                property bool hasIcon: iconData !== null
                property var icons: SettingsData.showWorkspaceApps ? root.getWorkspaceIcons(CompositorService.isHyprland ? modelData : (modelData === -1 ? null : modelData)) : []

                width: {
                    if (SettingsData.showWorkspaceApps) {
                        if (icons.length > 0) {
                            return isActive ? widgetHeight * 1.0 + Theme.spacingXS + contentRow.implicitWidth : widgetHeight * 0.8 + contentRow.implicitWidth
                        } else {
                            return isActive ? widgetHeight * 1.0 + Theme.spacingXS : widgetHeight * 0.8
                        }
                    }
                    return isActive ? widgetHeight * 1.2 + Theme.spacingXS : widgetHeight * 0.8
                }
                height: SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
                radius: height / 2
                color: isActive ? Theme.primary : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (isPlaceholder) {
                            return
                        }

                        if (CompositorService.isNiri) {
                            NiriService.switchToWorkspace(modelData - 1)
                        } else if (CompositorService.isHyprland && modelData?.id) {
                            Hyprland.dispatch(`workspace ${modelData.id}`)
                        }
                    }
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 4
                    visible: SettingsData.showWorkspaceApps && icons.length > 0

                    Repeater {
                        model: icons.slice(0, SettingsData.maxWorkspaceIcons)
                        delegate: Item {
                            width: 18
                            height: 18

                            IconImage {
                                id: appIcon
                                property var windowId: modelData.windowId
                                anchors.fill: parent
                                source: modelData.icon
                                opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                MouseArea {
                                    id: appMouseArea
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    enabled: isActive
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (CompositorService.isHyprland) {
                                            Hyprland.dispatch(`focuswindow address:${appIcon.windowId}`)
                                        } else if (CompositorService.isNiri) {
                                            NiriService.focusWindow(appIcon.windowId)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: modelData.count > 1 && !isActive
                                width: 12
                                height: 12
                                radius: 6
                                color: "black"
                                border.color: "white"
                                border.width: 1
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                z: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    font.pixelSize: 8
                                    color: "white"
                                }
                            }
                        }
                    }
                }

                DankIcon {
                    visible: hasIcon && iconData.type === "icon" && (!SettingsData.showWorkspaceApps || icons.length === 0)
                    anchors.centerIn: parent
                    name: (hasIcon && iconData.type === "icon") ? iconData.value : ""
                    size: Theme.fontSizeSmall
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    weight: isActive && !isPlaceholder ? 500 : 400
                }

                StyledText {
                    visible: hasIcon && iconData.type === "text" && (!SettingsData.showWorkspaceApps || icons.length === 0)
                    anchors.centerIn: parent
                    text: (hasIcon && iconData.type === "text") ? iconData.value : ""
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                }

                StyledText {
                    visible: (SettingsData.showWorkspaceIndex && !hasIcon && (!SettingsData.showWorkspaceApps || icons.length === 0))
                    anchors.centerIn: parent
                    text: {
                        const isPlaceholder = CompositorService.isHyprland ? (modelData?.id === -1) : (modelData === -1)

                        if (isPlaceholder) {
                            return index + 1
                        }

                        return CompositorService.isHyprland ? (modelData?.id || "") : (modelData - 1)
                    }
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                }

                Behavior on width {
		    // When having more icons, animation becomes clunky
		    enabled: (!SettingsData.showWorkspaceApps || SettingsData.maxWorkspaceIcons <= 3)
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                Behavior on color {
		    // When having more icons, animation becomes clunky
		    enabled: (!SettingsData.showWorkspaceApps || SettingsData.maxWorkspaceIcons <= 3)
                    ColorAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }
}
