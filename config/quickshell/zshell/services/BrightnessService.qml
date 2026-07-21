pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Single source of truth for brightness, so the quick-settings slider
// and the new OSD popup (and anything else, later) all stay in sync
// regardless of which one actually changed it.
//
// `value` is deliberately a plain writable property, not readonly:
// callers (BrightnessSlider's drag/scroll, the OSD's hotkey handlers)
// assign to it directly for instant, synchronous visual feedback
// everywhere it's bound, and separately call commit() to actually
// apply it via brightnessctl (which involves a real subprocess and
// should be debounced/throttled by the caller if it fires rapidly).
QtObject {
    id: root

    property real value: 0   // 0.0-1.0

    function refresh() {
        queryProc.running = true;
    }

    // Actually applies a percentage via brightnessctl. Does NOT itself
    // debounce - callers driving this from rapid-fire input (dragging,
    // scrolling) should debounce on their end; a single hotkey press
    // calling this directly is fine.
    function commit(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));
        setProc.command = ["brightnessctl", "set", clamped + "%"];
        setProc.running = true;
        root.value = clamped / 100;
    }

    // Convenience for hotkey-driven +/- steps (used by the OSD).
    // Debounced internally: Hyprland's "binde" (hold-to-repeat) fires
    // this very rapidly while a key is held, and spawning a real
    // brightnessctl subprocess on every single repeat tick would be
    // wasteful and can visibly lag. The displayed value still updates
    // instantly every tick - only the actual system call is throttled.
    property real _pendingPct: 0

    function increase(stepPct) {
        _stepBy(stepPct);
    }

    function decrease(stepPct) {
        _stepBy(-stepPct);
    }

    function _stepBy(deltaPct) {
        const clamped = Math.max(0, Math.min(100, root.value * 100 + deltaPct));
        root.value = clamped / 100;
        _pendingPct = clamped;
        _repeatDebounce.restart();
    }

    property Timer _repeatDebounce: Timer {
        interval: 60
        onTriggered: root.commit(root._pendingPct)
    }

    // `brightnessctl -m` prints one machine-readable line, e.g.:
    //   intel_backlight,backlight,660,77%,1320
    // Field index 3 is the percentage - already computed for us.
    property Process queryProc: Process {
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",");
                if (parts.length >= 4) {
                    const pct = parseInt(parts[3].replace("%", ""), 10);
                    if (!isNaN(pct))
                        root.value = pct / 100;
                }
            }
        }
    }

    property Process setProc: Process {}

    Component.onCompleted: refresh()
}