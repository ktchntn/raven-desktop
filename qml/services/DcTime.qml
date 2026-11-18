pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// RAVEN: is the clock on a domain controller's time (bin/raven-dctime, `dctime IP`)? Read from
// $XDG_RUNTIME_DIR/raven-dctime.json every 3 s for the bar's lime clock.
Singleton {
    id: root

    property bool active: false
    property string dc: ""
    property real offset: 0

    Process {
        id: reader
        command: ["sh", "-c", "cat \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/raven-dctime.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = null;
                try {
                    s = text.trim() ? JSON.parse(text) : null;
                } catch (e) {
                }
                root.active = s !== null;
                root.dc = s?.dc ?? "";
                root.offset = s?.offset ?? 0;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }
}
