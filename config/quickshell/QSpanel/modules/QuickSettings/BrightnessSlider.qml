import QtQuick
import "../../services"


SliderCard {
    id: root

    label: "System Brightness"
    fillColor: Colors.blue
    iconSource: Qt.resolvedUrl("../../assets/icons/brightness.svg")

    value: BrightnessService.value

   
    property real pendingValue: value

    Timer {
        id: debounce
        interval: 80
        onTriggered: BrightnessService.commit(root.pendingValue * 100)
    }

    onMoved: newValue => {
        
        BrightnessService.value = newValue;
        pendingValue = newValue;
        debounce.restart();
    }
}