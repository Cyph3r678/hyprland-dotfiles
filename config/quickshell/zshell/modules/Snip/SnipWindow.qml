import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "."

// Fullscreen screenshot/screen-recording overlay for the currently
// focused monitor. Toggled via shell.qml's IPC "snip" target:
//
//   SnipWindow { id: snipWindow }
//
//   IpcHandler {
//       target: "snip"
//       function toggle(): void { snipWindow.toggle(); }
//       function show(): void { snipWindow.show(); }
//       function hide(): void { snipWindow.hide(); }
//   }
//
// Requires `grim`, `wf-recorder`, and `pactl` (for system audio) on
// PATH. Screenshots save to ~/Pictures/Screenshots, recordings to
// ~/Videos.
//
// IMPORTANT: add this to hyprland.conf - it targets the *recording*
// controls bar's namespace specifically, NOT this window's:
//   layerrule = no_screen_share on, match:namespace qspanel:snip-recording
//
// This window (namespace "qspanel:snip") deliberately does NOT get
// that rule. no_screen_share excludes a surface's entire occupied
// region from any screencopy, not just its own drawn pixels - since
// this window is fullscreen, applying it here would black out the
// whole capture (screenshot or recording), not just our own chrome.
// Screenshots avoid needing it at all by fully hiding this window
// before calling grim. Recording avoids it by handing off to a
// completely separate, small, always-fixed-bottom window
// (SnipRecordingBar.qml) the instant recording starts - which is only
// ever mapped once THIS window has already fully unmapped, so there's
// no stacking-order fight between two simultaneously-visible surfaces
// either.
PanelWindow {
    id: window

    // Hidden either when the tool is fully closed, or once recording
    // has taken over (SnipRecordingBar handles everything from there).
    property bool panelVisible: false
    visible: panelVisible && !recordingActive

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qspanel:snip"

    // ---- selection state, in this window's local (logical-pixel)
    // space, matching whatever coordinate space `screen` reports ----
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property bool hasSelection: false
    property bool isFullscreenSel: false
    property var storedSel: null
    readonly property real minSelSize: 20

    // ---- mode / recording state ----
    property bool recordingMode: false // false = screenshot, true = recording
    property bool recordingActive: false
    property bool recordingPaused: false
    property int elapsedSeconds: 0

    function clampSelection() {
        selX = Math.max(0, Math.min(selX, width - minSelSize));
        selY = Math.max(0, Math.min(selY, height - minSelSize));
        selW = Math.max(minSelSize, Math.min(selW, width - selX));
        selH = Math.max(minSelSize, Math.min(selH, height - selY));
    }

    function show() {
        panelVisible = true;
        overlay.forceActiveFocus();
    }

    function hide() {
        panelVisible = false;
    }

    function toggle() {
        if (panelVisible)
            hide();
        else
            show();
    }

    function resetAndClose() {
        hasSelection = false;
        isFullscreenSel = false;
        storedSel = null;
        recordingMode = false;
        recordingActive = false;
        recordingPaused = false;
        elapsedSeconds = 0;
        hide();
    }

    Timer {
        interval: 1000
        repeat: true
        running: window.recordingActive && !window.recordingPaused
        onTriggered: window.elapsedSeconds += 1
    }

    // ---- geometry conversion for grim/wf-recorder ----
    // Both want physical-pixel geometry as "X,Y WxH", relative to the
    // whole compositor layout - not just this monitor's local pixels
    // - so we need this monitor's absolute offset and scale from
    // Hyprland, not just our own selX/selY/selW/selH.
    readonly property var hyprMonitor: window.screen
        ? Hyprland.monitors.values.find(m => m.name === window.screen.name)
        : null

    function geometryString() {
        const m = window.hyprMonitor;
        const scale = m ? m.scale : 1;
        const offX = m ? m.x : 0;
        const offY = m ? m.y : 0;
        const px = Math.round(offX + window.selX * scale);
        const py = Math.round(offY + window.selY * scale);
        const pw = Math.round(window.selW * scale);
        const ph = Math.round(window.selH * scale);
        return px + "," + py + " " + pw + "x" + ph;
    }

    function timestamp() {
        const d = new Date();
        const pad = n => String(n).padStart(2, "0");
        return d.getFullYear() + "" + pad(d.getMonth() + 1) + pad(d.getDate())
            + "_" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
    }

    // ---- screenshot ----
    // Hide this window first so our own UI never ends up in the shot,
    // then wait a beat for the compositor to actually finish
    // unmapping/recompositing before calling grim. Since this
    // namespace never has no_screen_share applied, there's no risk of
    // an unmap-timing race blacking out the whole shot the way there
    // would be if the rule targeted this fullscreen window - worst
    // case here if the delay is ever too short is our own overlay
    // showing through faintly, not a corrupted capture.
    Process {
        id: screenshotProc
        command: ["bash", "-c",
            "mkdir -p ~/Pictures/Screenshots && grim -g '" + window.geometryString()
            + "' ~/Pictures/Screenshots/Screenshot_" + window.timestamp() + ".png"]
        onExited: window.resetAndClose()
    }

    Timer {
        id: screenshotDelay
        interval: 150
        onTriggered: screenshotProc.running = true
    }

    function takeScreenshot() {
        if (!window.hasSelection)
            return;
        window.panelVisible = false;
        screenshotDelay.start();
    }

    // ---- recording ----
    // `exec` replaces the wrapping bash process with wf-recorder
    // directly, so pkill -f below matches (and signals) wf-recorder
    // itself with no intermediate process in the way. `-a=...monitor`
    // records the default output sink's monitor - i.e. system/device
    // audio (what's playing), not the microphone, which is what a
    // bare `-a` with no device would default to.
    Process {
        id: recordProc
        command: ["bash", "-c",
            "mkdir -p ~/Videos && exec wf-recorder -g '" + window.geometryString()
            + "' -a=$(pactl get-default-sink).monitor -f ~/Videos/Recording_" + window.timestamp() + ".mp4"]
    }

    Process {
        id: pauseProc
        command: ["pkill", "-STOP", "-f", "wf-recorder"]
    }

    Process {
        id: resumeProc
        command: ["pkill", "-CONT", "-f", "wf-recorder"]
    }

    Process {
        id: stopProc
        command: ["pkill", "-INT", "-f", "wf-recorder"]
        onExited: window.resetAndClose()
    }

    Timer {
        id: stopDelay
        interval: 150
        onTriggered: stopProc.running = true
    }

    function startRecording() {
        if (!window.hasSelection)
            return;
        // recordProc's command reads geometryString() at the moment
        // .running is set true below - selX/Y/W/H are still whatever
        // they were when you finished dragging, unaffected by this
        // window unmapping itself right after.
        window.recordingActive = true;
        window.recordingPaused = false;
        window.elapsedSeconds = 0;
        recordProc.running = true;
    }

    function startCapture() {
        if (window.recordingMode)
            window.startRecording();
        else
            window.takeScreenshot();
    }

    function togglePause() {
        if (!window.recordingPaused) {
            pauseProc.running = true;
            window.recordingPaused = true;
        } else {
            resumeProc.running = true;
            window.recordingPaused = false;
        }
    }

    // Stopping while paused needs the process resumed (SIGCONT)
    // FIRST - a process frozen by SIGSTOP doesn't process *any*
    // signal, including SIGINT, until it's running again. Sending
    // SIGINT straight to a stopped wf-recorder left it stuck mid-mux
    // with the MP4's moov atom never written, which is what was
    // producing the corrupted, unplayable files.
    function stopAndSave() {
        if (window.recordingPaused) {
            resumeProc.running = true;
            window.recordingPaused = false;
            stopDelay.start();
        } else {
            stopProc.running = true;
        }
    }

    SnipOverlay {
        id: overlay
        anchors.fill: parent
        window: window
    }

    SnipControls {
        window: window
    }

    // Only ever mapped once this window has already fully unmapped
    // (window.visible above is false as soon as recordingActive
    // flips true) - never simultaneously visible with this one, so
    // there's no cross-surface stacking order to fight over.
    SnipRecordingBar {
        window: window
    }
}