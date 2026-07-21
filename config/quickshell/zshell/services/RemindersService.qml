pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Reminders persist to disk via Quickshell's FileView + JsonAdapter
// pattern, so they survive a restart instead of being purely in-memory.
QtObject {
    id: root

    property alias reminders: jsonAdapter.reminders

    function add(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return;
        // Reassigning the whole list (not push()) is what triggers the
        // JsonAdapter's change notification correctly.
        jsonAdapter.reminders = [...jsonAdapter.reminders, trimmed];
    }

    function removeAt(index) {
        const copy = [...jsonAdapter.reminders];
        copy.splice(index, 1);
        jsonAdapter.reminders = copy;
    }

    property FileView fileView: FileView {
        // Quickshell.dataPath() is the reserved per-shell data
        // directory - avoids hardcoding a home-directory path.
        path: Quickshell.dataPath("reminders.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: jsonAdapter
            property list<string> reminders: []
        }
    }
}