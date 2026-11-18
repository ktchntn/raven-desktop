pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// RAVEN: quick settings' Burp tile (bin/raven-burp). On = both browsers go through
// 127.0.0.1:<port> (the system proxy, followed live by Firefox and Chromium). If the proxy is on
// but nothing listens there for a while (Burp closed), one notification offers to turn it off,
// since every page would fail to load.
Singleton {
    id: root

    property bool proxy: false
    property bool listening: false
    property int port: 8080
    property bool known: false
    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/raven-burp"

    function parse(text: string): void {
        let s;
        try {
            s = JSON.parse(text);
        } catch (e) {
            return;
        }
        root.proxy = !!s.proxy;
        root.listening = !!s.listening;
        root.port = s.port ?? 8080;
        root.known = true;
    }

    function toggle(): void {
        root.proxy = !root.proxy;                 // show it at once; the next read confirms
        Quickshell.execDetached([root.helper, root.proxy ? "on" : "off"]);
        refresh.restart();
    }

    readonly property bool stranded: known && proxy && !listening
    property bool warned: false
    onStrandedChanged: {
        if (stranded) strandTimer.restart();
        else { strandTimer.stop(); warned = false; }
    }

    Timer {
        id: strandTimer
        interval: 12000
        onTriggered: {
            if (!root.stranded || root.warned) return;
            root.warned = true;
            Quickshell.execDetached([Config.cmd.sh, "-c", `
                a=$(notify-send --app-name=Burp --hint=string:x-raven-tag:burp --action=off="Turn proxy off" \\
                    "Burp isn't listening" "The browsers still go through 127.0.0.1:$1, so pages won't load")
                [ "$a" = off ] && exec "$2" off`, "sh", String(root.port), root.helper]);
        }
    }

    Process {
        id: reader
        command: [root.helper, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }

    Timer {
        id: refresh
        interval: 400
        onTriggered: if (!reader.running) reader.running = true
    }
}
