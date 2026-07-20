pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Thin wrapper around Quickshell's native Quickshell.Bluetooth module
// (which talks to BlueZ over DBus directly - no shelling out needed,
// unlike WifiService). Kept as its own singleton mainly so BluetoothTile
// doesn't need to null-check `Bluetooth.defaultAdapter` everywhere.
QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    // Every device BlueZ currently knows about for this adapter - both
    // paired/previously-connected devices and freshly discovered ones
    // while discovering is true. Each device carries its own
    // .paired/.connected/.pairing state - the UI reads those directly.
    //
    // IMPORTANT: adapter.devices is a Quickshell ObjectModel, not a plain
    // JS array (same situation as Mpris.players earlier) - .values is
    // what actually gives us something with a working .length, index
    // access, and for-of support.
    readonly property var devices: adapter?.devices?.values ?? []

    onAdapterChanged: console.log("[BluetoothService] adapter:", adapter)
    onAvailableChanged: console.log("[BluetoothService] available:", available)
    onEnabledChanged: console.log("[BluetoothService] enabled:", enabled)
    onDiscoveringChanged: console.log("[BluetoothService] discovering:", discovering)
    onDevicesChanged: {
        console.log("[BluetoothService] devices.length:", devices.length);
        for (const d of devices)
            console.log("  -", d.name, "paired:", d.paired, "connected:", d.connected);
    }

    readonly property string connectedName: {
        for (const d of devices) {
            if (d.connected)
                return d.name;
        }
        return "";
    }

    function toggle() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function startScan() {
        if (adapter)
            adapter.discovering = true;
    }

    function stopScan() {
        if (adapter)
            adapter.discovering = false;
    }

    // Calling connect() on an unpaired device makes BlueZ run the pairing
    // flow first and then connect - there's no separate pair() call.
    function connectDevice(device) {
        device.connect();
    }

    function disconnectDevice(device) {
        device.disconnect();
    }

    function forgetDevice(device) {
        device.forget();
    }
}