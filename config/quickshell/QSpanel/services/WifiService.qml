pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Wraps nmcli so the UI never has to know about process/parsing details.
// WifiTile just reads `enabled`/`networks`/`connectedSsid` and calls
// toggle()/scan()/connectToNetwork().
QtObject {
    id: root

    property bool enabled: false
    property bool scanning: false
    property bool connecting: false
    property string connectingSsid: ""
    property string connectedSsid: ""
    property string lastError: ""
    // Each entry: { ssid, signal (0-100), secured (bool), inUse (bool) }
    property var networks: []

    function refreshRadio() {
        console.log("[WifiService] refreshRadio() called");
        radioProc.running = true;
    }

    function scan() {
        scanning = true;
        // "nmcli dev wifi list --rescan yes" forces a fresh scan instead
        // of returning NetworkManager's cached list.
        scanProc.running = true;
    }

    function toggle() {
        console.log("[WifiService] toggle() called, current enabled =", root.enabled);
        toggleProc.command = ["nmcli", "radio", "wifi", root.enabled ? "off" : "on"];
        console.log("[WifiService] running command:", JSON.stringify(toggleProc.command));
        toggleProc.running = true;
    }

    function connectToNetwork(ssid, password) {
        connecting = true;
        connectingSsid = ssid;
        lastError = "";
        if (password && password.length > 0) {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password];
        } else {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        }
        connectProc.running = true;
    }

    // ---- processes ----
    // NOTE: plain QtObject has no default property that accepts bare
    // nested children (that's an Item-only feature), so every Process/
    // Timer here MUST be attached via an explicit `property X name:`
    // declaration rather than just nested directly.

    property Process radioProc: Process {
        // "nmcli radio wifi" can print a localized string on non-English
        // locales (not literally "enabled"/"disabled"), which broke exact
        // matching. Terse (-t) general status is locale-stable.
        command: ["nmcli", "-t", "-f", "WIFI", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[WifiService] radio raw output:", JSON.stringify(this.text));
                root.enabled = this.text.trim().toLowerCase().includes("enabled");
                console.log("[WifiService] enabled set to:", root.enabled);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.lastError = "radio check: " + this.text.trim();
            }
        }
    }

    property Process scanProc: Process {
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const seen = new Set();
                const result = [];
                let currentSsid = "";

                for (const line of lines) {
                    if (!line)
                        continue;
                    // Fields are colon separated: IN-USE:SSID:SIGNAL:SECURITY
                    // SSID itself won't normally contain a colon in nmcli's
                    // terse output (it escapes them), so this simple split
                    // is fine for the vast majority of networks.
                    const parts = line.split(":");
                    const inUse = parts[0] === "*";
                    const ssid = parts[1] ?? "";
                    const signal = parseInt(parts[2] ?? "0", 10) || 0;
                    const security = parts[3] ?? "";

                    if (!ssid || seen.has(ssid))
                        continue;
                    seen.add(ssid);

                    if (inUse)
                        currentSsid = ssid;

                    result.push({
                        ssid: ssid,
                        signal: signal,
                        secured: security.length > 0,
                        inUse: inUse
                    });
                }

                result.sort((a, b) => b.signal - a.signal);
                root.networks = result;
                root.connectedSsid = currentSsid;
                root.scanning = false;
            }
        }
    }

    property Process toggleProc: Process {
        onExited: root.refreshRadio()
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.lastError = "toggle: " + this.text.trim();
            }
        }
    }

    property Process connectProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.connecting = false;
                root.connectingSsid = "";
                if (!this.text.toLowerCase().includes("success")) {
                    root.lastError = this.text.trim();
                }
                root.scan();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    root.lastError = this.text.trim();
                    root.connecting = false;
                    root.connectingSsid = "";
                }
            }
        }
    }

    // Poll periodically so external changes (connecting via your DE's
    // own network settings, walking out of range, etc.) stay reflected.
    property Timer pollTimer: Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            root.refreshRadio();
            if (root.enabled)
                root.scan();
        }
    }

    Component.onCompleted: {
        refreshRadio();
        scan();
    }
}