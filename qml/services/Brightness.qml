pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// RAVEN: replaces NIHIL's Brightness.qml. NIHIL ran `brightnessctl -m`, which on a machine
// without a backlight (this Parallels VM) picks the first LED it finds (Num Lock, max 1), so the
// quick settings slider drove the Num Lock light and always read 0. Here only the backlight
// class counts; with none, `available` stays false and the slider is hidden (the user sets
// brightness with the Mac's keys; software dimming was tried and dropped, 2026-11-16).
Singleton {
    id: root

    property real value: 0
    property bool available: false

    function refresh(): void {
        if (!reader.running) reader.running = true;
    }

    function set(v: real): void {
        if (!available) return;
        const percent = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        value = percent / 100;
        Quickshell.execDetached([Config.cmd.brightnessctl, "-c", "backlight", "set", percent + "%"]);
    }

    Process {
        id: reader
        command: [Config.cmd.brightnessctl, "-c", "backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5 && parseInt(f[4]) > 0) {
                    root.value = parseInt(f[2]) / parseInt(f[4]);
                    root.available = true;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
