import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"
import "."

// Fullscreen wallpaper picker, overlaying everything on screen.
// Toggled via shell.qml's IPC "wallpaper" target:
//
//   WallpaperWindow { id: wallpaperWindow }
//
//   IpcHandler {
//       target: "wallpaper"
//       function toggle(): void { wallpaperWindow.toggle(); }
//       function show(): void { wallpaperWindow.show(); }
//       function hide(): void { wallpaperWindow.hide(); }
//   }
//
// Applies wallpapers via `awww img <path>` - requires an awww-daemon
// already running (same exec-once you'd already need for swww, just
// renamed). Directory picking tries `zenity --file-selection
// --directory` first, falling back to `kdialog --getexistingdirectory`
// if zenity isn't installed - see pickDirProc below.
PanelWindow {
    id: window

    PersistentProperties {
        id: persist
        reloadableId: "qspanel-wallpaper-window"
        property bool panelVisible: false
        // 0 = hidden (off-screen above), 1 = fully open.
        property real openProgress: 0
        // Both live here (not as plain properties below) specifically
        // so they survive a config reload instead of silently
        // resetting back to defaults - that's what was actually
        // happening whenever a reload occurred while this was open.
        property string currentDir: "~/Pictures/Wallpapers"
        property bool gridView: false

        Behavior on openProgress {
            NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
        }
    }

    visible: persist.openProgress > 0.001

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qspanel:wallpaper"

    function show() {
        persist.panelVisible = true;
        persist.openProgress = 1;
        if (images.length === 0)
            rescan();
        content.forceActiveFocus();
    }

    function hide() {
        persist.panelVisible = false;
        persist.openProgress = 0;
    }

    function toggle() {
        if (persist.panelVisible)
            hide();
        else
            show();
    }

    // ---- directory + image list ----
    property alias currentDir: persist.currentDir
    property var images: [] // full paths, unfiltered
    property string searchQuery: ""
    property int currentIndex: -1
    property alias gridView: persist.gridView // false = parallelogram carousel, true = file-manager grid

    readonly property var filteredImages: {
        if (searchQuery.trim() === "")
            return images;
        const q = searchQuery.toLowerCase();
        return images.filter(p => fileName(p).toLowerCase().includes(q));
    }

    readonly property string currentImage:
        (currentIndex >= 0 && currentIndex < filteredImages.length)
            ? filteredImages[currentIndex] : ""

    // Approximate columns for the grid view's keyboard navigation -
    // just needs to roughly match WallpaperGrid.qml's own cellWidth
    // (280), doesn't need to be pixel-perfect.
    readonly property int gridColumns: Math.max(1, Math.floor((width - 40) / 280))

    function fileName(path) {
        const parts = path.split("/");
        return parts[parts.length - 1];
    }

    function selectIndex(i) {
        if (filteredImages.length === 0) {
            currentIndex = -1;
            return;
        }
        currentIndex = Math.max(0, Math.min(i, filteredImages.length - 1));
    }

    onSearchQueryChanged: selectIndex(0)

    // ---- directory scan ----
    Process {
        id: scanProc
        // A leading "~" does NOT expand inside double quotes in bash
        // - "find \"~/Pictures/Wallpapers\" ..." was literally
        // searching for a directory named "~", which never exists.
        // Swapping it for $HOME fixes that, since $HOME *does* expand
        // inside double quotes. This is why the default directory
        // (and anything else starting with ~) never loaded anything.
        readonly property string expandedDir: window.currentDir.startsWith("~")
            ? ("$HOME" + window.currentDir.slice(1))
            : window.currentDir
        command: ["bash", "-c",
            "find \"" + expandedDir + "\" -maxdepth 1 -type f "
            + "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) | sort"]
        property var lines: []
        stdout: SplitParser {
            onRead: line => scanProc.lines.push(line)
        }
        onStarted: scanProc.lines = []
        onExited: {
            window.images = scanProc.lines;
            window.currentIndex = window.images.length > 0 ? 0 : -1;
        }
    }

    function rescan() {
        scanProc.running = true;
    }

    // ---- directory: plain text entry now, no external picker ----
    // zenity/kdialog spawn a normal toplevel window, which is
    // structurally stuck behind this fullscreen overlay-layer surface
    // no matter what we do (Hyprland's overlay layer always renders
    // above regular windows by design) - hiding this window around
    // the picker call was the workaround, but that's real added
    // complexity for something a plain text field sidesteps entirely.
    function commitDirectory(path) {
        const trimmed = path.trim();
        if (trimmed === "" || trimmed === window.currentDir)
            return;
        window.currentDir = trimmed;
        window.searchQuery = "";
        window.rescan();
    }

    // ---- apply wallpaper ----
    Process {
        id: applyProc
        command: ["awww", "img", window.currentImage]
    }

    function applySelected() {
        if (window.currentImage === "")
            return;
        applyProc.running = true;
        window.hide();
    }

    // Slides down from off-screen above into place - everything
    // (background preview, top bar, both views) lives inside this so
    // it all moves together as one piece.
    Item {
        id: slideContainer
        anchors.fill: parent
        y: (1 - persist.openProgress) * -height

        // ---- background: blurred, dimmed live preview of the
        // selected image, filling the whole window behind everything
        // else ----
        // Restored - the earlier segfaults turned out to be caused by
        // the top bar's MultiEffects being children of their own
        // source (a genuinely malformed scenegraph relationship, now
        // fixed), not this blur. This one was always a proper sibling
        // of bgImage, so it was never actually the problem - it just
        // got pulled defensively while the real cause was still
        // unidentified.
        Image {
            id: bgImage
            anchors.fill: parent
            source: window.currentImage
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        MultiEffect {
            anchors.fill: parent
            source: bgImage
            blurEnabled: window.currentImage !== ""
            blur: 1.0
            blurMax: 64
            autoPaddingEnabled: false
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.20
        }

        Item {
            id: content
            anchors.fill: parent
            focus: true

        Keys.onEscapePressed: window.hide()
        Keys.onReturnPressed: window.applySelected()
        Keys.onEnterPressed: window.applySelected()
        Keys.onLeftPressed: window.selectIndex(window.currentIndex - 1)
        Keys.onRightPressed: window.selectIndex(window.currentIndex + 1)
        Keys.onUpPressed: if (window.gridView) window.selectIndex(window.currentIndex - window.gridColumns)
        Keys.onDownPressed: if (window.gridView) window.selectIndex(window.currentIndex + window.gridColumns)

        // ---- top bar ----
        RowLayout {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 16

            // left: wallpaper icon + item count + directory path entry
            Item {
                id: leftWrap
                Layout.preferredHeight: 48
                Layout.preferredWidth: leftRow.implicitWidth + 24

                MultiEffect {
                    source: leftBg
                    anchors.fill: leftBg
                    z: -1
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 0.8
                    shadowOpacity: 0.6
                }

                Rectangle {
                    id: leftBg
                    anchors.fill: parent
                    radius: 16
                    color: Colors.bg0
                }

                RowLayout {
                    id: leftRow
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: Colors.bg2

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/wallpaper.svg")
                            width: 18
                            height: 18
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: countText.implicitWidth + 20
                        radius: 10
                        color: Colors.bg2

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            font.family: Colors.fontFamily
                            text: window.images.length + " items"
                            color: Colors.fg
                            font.pixelSize: 13
                        }
                    }

                    // Type or paste a directory path, then press
                    // Enter to scan it. Replaces the old zenity/
                    // kdialog picker - see commitDirectory() above.
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 220
                        radius: 10
                        color: Colors.bg2

                        TextInput {
                            id: dirInput
                            anchors.fill: parent
                            font.family: Colors.fontFamily
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.fg
                            font.pixelSize: 13
                            clip: true
                            text: window.currentDir
                            selectByMouse: true
                            onAccepted: window.commitDirectory(text)
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // center: search
            Item {
                Layout.rightMargin: 264
                Layout.preferredWidth: 320
                Layout.preferredHeight: 48

                MultiEffect {
                    source: searchBg
                    anchors.fill: searchBg
                    z: -1
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 0.8
                    shadowOpacity: 0.6
                }

                Rectangle {
                    id: searchBg
                    anchors.fill: parent
                    radius: 16
                    color: Colors.bg0
                }

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.fg
                    font.pixelSize: 14
                    font.family: Colors.fontFamily
                    clip: true
                    text: window.searchQuery
                    onTextChanged: window.searchQuery = text

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search...."
                        font.family: Colors.fontFamily
                        color: Colors.fg
                        opacity: 0.4
                        font.pixelSize: 14
                        visible: parent.text === ""
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // right: switch view
            Item {
                Layout.preferredHeight: 48
                Layout.preferredWidth: switchText.implicitWidth + 32

                MultiEffect {
                    source: switchBg
                    anchors.fill: switchBg
                    z: -1
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 0.8
                    shadowOpacity: 0.6
                }

                Rectangle {
                    id: switchBg
                    anchors.fill: parent
                    radius: 16
                    color: Colors.bg0
                }

                Text {
                    id: switchText
                    anchors.centerIn: parent
                    text: "Switch view"
                    font.family: Colors.fontFamily
                    color: Colors.fg
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: window.gridView = !window.gridView
                }
            }
        }

        // Both instantiated directly (not through a Loader+Component)
        // and toggled via visible - the Loader/Component indirection
        // was the likely cause of `window` coming through as
        // undefined at runtime inside the carousel (matches the
        // "Cannot read property 'filteredImages' of undefined"
        // warnings from the crash log, and the symptom of the grid
        // rendering nothing despite the item count/background preview
        // both being correct upstream). Direct property binding here
        // is the same pattern already proven to work everywhere else
        // in this project.
        WallpaperCarousel {
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 40
            anchors.bottomMargin: 40
            window: window
            visible: !window.gridView
        }

        WallpaperGrid {
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 80
            anchors.bottomMargin: 80
            anchors.leftMargin: 225
            window: window
            visible: window.gridView
        }
        }
    }
}