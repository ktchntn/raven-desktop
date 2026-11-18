pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// RAVEN: the listeners you started (nc, http.server, ligolo, chisel...), from
// ~/.local/bin/raven-listeners every 3 s. Clicking one copies LHOST:port while a VPN is up.
Singleton {
    id: root

    property var list: []               // [{ proto, addr, port, proc, pid }]
    readonly property bool any: list.length > 0
    property string copied: ""

    // What a click copies: tun0-address:port when the listener is reachable over the VPN.
    function target(l: var): string {
        if (Vpn.active && (l.addr === "all" || l.addr === Vpn.ip))
            return Vpn.ip + ":" + l.port;
        return String(l.port);
    }

    function copy(l: var): void {
        const text = root.target(l);
        Quickshell.execDetached([Config.cmd.wlCopy, "--", text]);
        root.copied = text;
        settle.restart();
    }

    Process {
        id: reader
        command: [Quickshell.env("HOME") + "/.local/bin/raven-listeners"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const found = JSON.parse(text);
                    if (JSON.stringify(found) !== JSON.stringify(root.list))
                        root.list = found;
                } catch (e) {}
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

    Timer {
        id: settle
        interval: 1600
        onTriggered: root.copied = ""
    }
}
