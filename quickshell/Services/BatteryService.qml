pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool batteryAvailable: device && device.ready && device.isLaptopBattery
    readonly property real batteryLevel: batteryAvailable ? Math.round(device.percentage * 100) : 0
    readonly property bool isCharging: batteryAvailable && device.state === UPowerDeviceState.Charging && device.changeRate > 0
    readonly property bool isPluggedIn: batteryAvailable && (device.state !== UPowerDeviceState.Discharging && device.state !== UPowerDeviceState.Empty)
    readonly property bool isLowBattery: batteryAvailable && batteryLevel <= 20
    readonly property string batteryHealth: {
        if (!batteryAvailable) {
            return "N/A"
        }

        if (device.healthSupported && device.healthPercentage > 0) {
            return `${Math.round(device.healthPercentage)}%`
        }

        if (device.energyCapacity > 0 && device.energy > 0) {
            const healthPercent = (device.energyCapacity / 90.0045) * 100
            return `${Math.round(healthPercent)}%`
        }

        return "N/A"
    }
    readonly property real batteryCapacity: batteryAvailable && device.energyCapacity > 0 ? device.energyCapacity : 0
    readonly property string batteryStatus: {
        if (!batteryAvailable) {
            return "No Battery"
        }

        if (device.state === UPowerDeviceState.Charging && device.changeRate <= 0) {
            return "Plugged In"
        }

        return UPowerDeviceState.toString(device.state)
    }
    readonly property bool suggestPowerSaver: batteryAvailable && isLowBattery && UPower.onBattery && (typeof PowerProfiles !== "undefined" && PowerProfiles.profile !== PowerProfile.PowerSaver)

    readonly property var bluetoothDevices: {
        const btDevices = []
        const bluetoothTypes = [UPowerDeviceType.BluetoothGeneric, UPowerDeviceType.Headphones, UPowerDeviceType.Headset, UPowerDeviceType.Keyboard, UPowerDeviceType.Mouse, UPowerDeviceType.Speakers]

        for (var i = 0; i < UPower.devices.count; i++) {
            const dev = UPower.devices.get(i)
            if (dev && dev.ready && bluetoothTypes.includes(dev.type)) {
                btDevices.push({
                                   "name": dev.model || UPowerDeviceType.toString(dev.type),
                                   "percentage": Math.round(dev.percentage),
                                   "type": dev.type
                               })
            }
        }
        return btDevices
    }

    function formatTimeRemaining() {
        if (!batteryAvailable) {
            return "Unknown"
        }

        const timeSeconds = isCharging ? device.timeToFull : device.timeToEmpty

        if (!timeSeconds || timeSeconds <= 0 || timeSeconds > 86400) {
            return "Unknown"
        }

        const hours = Math.floor(timeSeconds / 3600)
        const minutes = Math.floor((timeSeconds % 3600) / 60)

        if (hours > 0) {
            return `${hours}h ${minutes}m`
        }

        return `${minutes}m`
    }
}
