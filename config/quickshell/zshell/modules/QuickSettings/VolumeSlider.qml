import Quickshell.Services.Pipewire
import QtQuick
import "../../services"


SliderCard {
    id: root

    label: "System Volume"
    fillColor: Colors.red

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false

    onSinkChanged: {
        console.log("[VolumeSlider] sink changed:", sink);
        console.log("[VolumeSlider] sink.ready:", sink?.ready);
        console.log("[VolumeSlider] sink.audio:", sink?.audio);
        console.log("[VolumeSlider] sink.audio.volume:", sink?.audio?.volume);
        console.log("[VolumeSlider] sink.name / description:", sink?.name, sink?.description);
    }

    iconSource: muted
        ? Qt.resolvedUrl("../../assets/icons/volume_muted.svg")
        : Qt.resolvedUrl("../../assets/icons/volume.svg")

    value: sink?.audio?.volume ?? 0

    PwObjectTracker {
        objects: [root.sink]
    }

    onMoved: newValue => {
        console.log("[VolumeSlider] onMoved, sink:", root.sink, "ready:", root.sink?.ready, "audio:", root.sink?.audio);
        if (root.sink?.ready && root.sink.audio) {
            root.sink.audio.muted = false;
            root.sink.audio.volume = newValue;
        } else {
            console.log("[VolumeSlider] write BLOCKED - sink not ready or no audio object");
        }
    }
}