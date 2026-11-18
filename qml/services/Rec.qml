pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// RAVEN: engagement logging (bin/raven-rec). Polls `raven-rec status --json` every 2 s for the
// bar's REC dot and quick settings' Log tile (switch + engagement picker).
Singleton {
    id: root

    property string engagement: ""
    property bool auto: false
    property var engagements: []
    property var recording: []
    readonly property bool active: recording.length > 0
    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/raven-rec"

    function parse(text: string): void {
        let s;
        try {
            s = JSON.parse(text);
        } catch (e) {
            return;
        }
        root.engagement = s.engagement ?? "";
        root.auto = !!s.auto;
        root.engagements = s.engagements ?? [];
        root.recording = s.recording ?? [];
    }

    function run(args: var): void {
        Quickshell.execDetached([root.helper].concat(args));
        refresh.restart();
    }

    // The switch needs an engagement: without one, turning it on just opens the picker.
    function toggle(): void { run([root.auto ? "off" : "on"]); }
    function use(name: string): void { run(["use", name]); }
    // Ends one recording like `rec stop` in its tab (an auto-recorded tab stays open, unrecorded).
    function stop(pid: var): void { run(["stop", String(pid)]); }

    Process {
        id: reader
        command: [root.helper, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }

    Timer {
        id: refresh
        interval: 300
        onTriggered: if (!reader.running) reader.running = true
    }
}
