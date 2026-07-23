import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "./modules/QuickSettings"
import "./modules/Osd"
import "./modules/PowerMenu"
import "./modules/Dock"
import "./modules/WorkspaceSwitcher"
import "./modules/Widgets"
import "./services"
import "./modules/Battery"
import "./modules/Snip"
import "./modules/Wallpaper"


// Every Quickshell config starts from one ShellRoot.
// It's not a visual element - it just holds everything else together.
ShellRoot {
    id: root

    // Single source of truth for whether the quick-settings panel is
    // open. QuickSettingsPanel just reflects this property; it never
    // decides its own visibility.
    property bool panelVisible: false

    // This is what waybar's on-click talks to.
    // From a terminal (or waybar's on-click config) you trigger it with:
    //   qs -c QSpanel ipc call quicksettings toggle
    IpcHandler {
        target: "quicksettings"

        function toggle(): void {
            root.panelVisible = !root.panelVisible;
        }

        function show(): void {
            root.panelVisible = true;
        }

        function hide(): void {
            root.panelVisible = false;
        }
    }

    IpcHandler {

    target: "wallpaper"
    function toggle(): void { wallpaperWindow.toggle(); }
    function show(): void { wallpaperWindow.show(); }
    function hide(): void { wallpaperWindow.hide(); }
    }

    // This is what your Hyprland brightness/volume keybinds talk to:
    //   qs -c QSpanel ipc call osd brightnessUp
    //   qs -c QSpanel ipc call osd brightnessDown
    //   qs -c QSpanel ipc call osd volumeUp
    //   qs -c QSpanel ipc call osd volumeDown
    // Each one applies the change AND pops the OSD - see OsdWindow.qml.
    IpcHandler {
        target: "osd"

        function brightnessUp(): void {
            BrightnessService.increase(5);
            osdWindow.show("brightness", BrightnessService.value);
        }

        function brightnessDown(): void {
            BrightnessService.decrease(5);
            osdWindow.show("brightness", BrightnessService.value);
        }

        function volumeUp(): void {
            const sink = Pipewire.defaultAudioSink;
            if (sink?.ready && sink.audio) {
                sink.audio.muted = false;
                sink.audio.volume = Math.min(1, sink.audio.volume + 0.05);
            }
            osdWindow.show("volume", sink?.audio?.volume ?? 0);
        }

        function volumeDown(): void {
            const sink = Pipewire.defaultAudioSink;
            if (sink?.ready && sink.audio) {
                sink.audio.volume = Math.max(0, sink.audio.volume - 0.05);
            }
            osdWindow.show("volume", sink?.audio?.volume ?? 0);
        }
    }

    // This is what waybar's power button on-click talks to:
    //   qs -c QSpanel ipc call powermenu toggle
    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            powerMenu.toggle();
        }

        function show(): void {
            powerMenu.show();
        }

        function hide(): void {
            powerMenu.hide();
        }
    }



    // This is what you'd wire a waybar button (or a keybind) to:
    //   qs -c QSpanel ipc call dock toggle
    IpcHandler {
        target: "dock"

        function toggle(): void {
            dock.toggle();
        }

        function show(): void {
            dock.show();
        }

        function hide(): void {
            dock.hide();
        }
    }

    // This is what your Hyprland workspace-switcher keybind talks to:
    //   qs -c QSpanel ipc call workspaceswitcher toggle
    // Scrolling/arrow-key navigation happens inside the switcher once
    // it's open - no extra IPC calls or Hyprland binds needed for that.
    IpcHandler {
        target: "workspaceswitcher"

        function toggle(): void {
            workspaceSwitcher.toggle();
        }

        function show(): void {
            workspaceSwitcher.show();
        }

        function hide(): void {
            workspaceSwitcher.hide();
        }
    }

    // This is what you'd wire a waybar button (or a keybind) to:
    //   qs -c QSpanel ipc call widgets toggle
    IpcHandler {
        target: "widgets"

        function toggle(): void {
            widgetsPanel.toggle();
        }

        function show(): void {
            widgetsPanel.show();
        }

        function hide(): void {
            widgetsPanel.hide();
        }
    }
    

    IpcHandler {

    target: "snip"
    function toggle(): void { snipWindow.toggle(); }
    function show(): void { snipWindow.show(); }
    function hide(): void { snipWindow.hide(); }
    
    }

    IpcHandler {

        target: "battery"
        function toggle(): void { batteryWindow.toggle(); }
        function show(): void { batteryWindow.show(); }
        function hide(): void { batteryWindow.hide(); }

    }

    // Pipewire nodes need a tracker to stay alive/reactive - same
    // requirement as in VolumeSlider.qml.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    QuickSettingsPanel {
        panelVisible: root.panelVisible
        // Lets the panel close itself, e.g. when it loses focus
        // or the user clicks outside it.
        onRequestClose: root.panelVisible = false
    }

    OsdWindow {
        id: osdWindow
    }

    PowerMenuWindow {
        id: powerMenu
    }

    DockWindow {
        id: dock
    }

    WorkspaceSwitcherWindow {
        id: workspaceSwitcher
    }

    WidgetsWindow {
        id: widgetsPanel
    }

    BatteryWindow { id: batteryWindow }

    SnipWindow { id: snipWindow }
    
    WallpaperWindow { id: wallpaperWindow }

}
