import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets

LazyLoader {
    active: SessionData.wallpaperPath !== ""

    Variants {
        model: SettingsData.getFilteredScreens("wallpaper")

        PanelWindow {
            id: wallpaperWindow

            required property var modelData

            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            color: "black"

            Item {
                id: root
                anchors.fill: parent

                property string source: SessionData.wallpaperPath || ""
                property Image current: one

                onSourceChanged: {
                    if (!source)
                        current = null
                    else if (current === one)
                        two.update()
                    else
                        one.update()
                }

                Loader {
                    anchors.fill: parent
                    active: !root.source
                    asynchronous: true

                    sourceComponent: Rectangle {
                        color: Theme.surface

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingL

                            DankIcon {
                                name: "sentiment_stressed"
                                color: Theme.surfaceVariantText
                                size: Theme.iconSize * 5
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                StyledText {
                                    text: "Wallpaper missing?"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeXLarge * 2
                                    font.weight: Font.Bold
                                }

                                StyledText {
                                    text: "Set wallpaper in Settings"
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeLarge
                                }
                            }
                        }
                    }
                }

                Img {
                    id: one
                }

                Img {
                    id: two
                }

                component Img: Image {
                    id: img

                    function update(): void {
                        source = ""
                        source = root.source
                    }

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    cache: false

                    opacity: 0

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            root.current = this
                            if (root.current === one && two.source) {
                                two.source = ""
                            } else if (root.current === two && one.source) {
                                one.source = ""
                            }
                        }
                    }

                    states: State {
                        name: "visible"
                        when: root.current === img

                        PropertyChanges {
                            img.opacity: 1
                        }
                    }

                    transitions: Transition {
                        NumberAnimation {
                            target: img
                            properties: "opacity"
                            duration: Theme.mediumDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
