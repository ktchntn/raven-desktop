pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// RAVEN: VPN tunnels (OpenVPN tun/tap, WireGuard wg, PPP, Tailscale...) that are up with an
// IPv4 address. Read from `ip -j -4 addr` every 2 s; the bar, dashboard and desktop widget
// swap in a VPN view while one is up.
// A NetworkManager profile (set up with `raven-vpn import FILE`) keeps the VPN card shown while
// down too, with one-click connect / disconnect through raven-vpn (no sudo).
Singleton {
    id: root

    property var tunnels: []            // [{ name, ip, prefix }], sorted by name
    readonly property bool active: tunnels.length > 0
    readonly property string name: active ? tunnels[0].name : ""
    readonly property string ip: active ? tunnels[0].ip : ""
    property string copied: ""          // the address just copied, for a moment

    // The raven-vpn profile: its NetworkManager name and state (up|connecting|down|none).
    property string profile: ""
    property string profileState: "none"
    property bool manual: false         // an openvpn started by hand (only root can stop it)
    property string error: ""
    property string pending: ""         // "up" / "down" while raven-vpn runs
    readonly property bool hasProfile: profile !== "" && profileState !== "none"
    readonly property bool shown: active || hasProfile
    readonly property bool busy: pending !== "" || profileState === "connecting"
    readonly property bool canConnect: hasProfile && !active && !busy && !manual
    readonly property bool canDisconnect: profileState === "up" && !busy

    // Traffic and uptime of the first tunnel (from /sys/class/net/<name>).
    property real rx: 0                 // bytes/s
    property real tx: 0
    property var rxHistory: []          // newest last, for DotScope
    property var txHistory: []
    property real since: 0              // when the interface appeared (epoch seconds)
    property real now: Date.now() / 1000
    property string statsFor: ""
    property real lastRx: -1
    property real lastTx: -1
    property real lastAt: 0

    readonly property string uptime: {
        if (!active || since <= 0)
            return "";
        const s = Math.max(0, Math.floor(now - since));
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m > 0 ? m + "m" : "<1m";
    }

    function push(list: var, value: real): var {
        const next = list.concat([value]);
        return next.length > 60 ? next.slice(next.length - 60) : next;
    }

    function readStats(text: string): void {
        const lines = text.trim().split("\n").map(Number);
        if (lines.length < 3 || lines.some(isNaN))
            return;
        const at = Date.now() / 1000;
        if (root.statsFor === root.name && root.lastRx >= 0 && at > root.lastAt) {
            const dt = at - root.lastAt;
            root.rx = Math.max(0, (lines[0] - root.lastRx) / dt);
            root.tx = Math.max(0, (lines[1] - root.lastTx) / dt);
            root.rxHistory = root.push(root.rxHistory, root.rx);
            root.txHistory = root.push(root.txHistory, root.tx);
        } else if (root.statsFor !== root.name) {
            root.rxHistory = [];
            root.txHistory = [];
            root.rx = 0;
            root.tx = 0;
        }
        root.statsFor = root.name;
        root.lastRx = lines[0];
        root.lastTx = lines[1];
        root.lastAt = at;
        root.since = lines[2];
    }

    readonly property var pattern: /^(tun|tap|wg|ppp|ipsec|vpn|tailscale|nordlynx|proton)/

    function copy(address: string): void {
        if (!address)
            return;
        Quickshell.execDetached([Config.cmd.wlCopy, "--", address]);
        root.copied = address;
        settle.restart();
    }

    function connect(): void {
        if (!root.canConnect) return;
        root.error = "";
        root.pending = "up";
        action.command = [root.helper, "up"];
        action.running = true;
    }

    function disconnect(): void {
        if (!root.canDisconnect) return;
        root.error = "";
        root.pending = "down";
        action.command = [root.helper, "down"];
        action.running = true;
    }

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/raven-vpn"

    // ---- Drop alarm: the tunnel went away and nobody asked for it (not the shell's power button,
    // not `raven-vpn down`, which leaves $XDG_RUNTIME_DIR/raven-vpn-down). After 4 s still down ->
    // critical notification (double lime sweep + sound) with a Reconnect button for the profile.
    // Anything else that takes it down (`nmcli connection down`, NetworkManager's applet) counts
    // as a drop.
    property string lastName: ""
    property string lastIp: ""
    property bool wasActive: false

    onIpChanged: {
        if (ip === "") return;
        if (lastIp !== "" && ip !== lastIp) ipAlarm(lastIp, ip);
        lastIp = ip;
        lastName = name;
    }

    // ---- New address after a reconnect: payloads, listeners' LHOST and callbacks made with the
    // old one are now wrong. Critical (sweep + sound), with the new address one click to copy.
    function ipAlarm(before: string, after: string): void {
        Quickshell.execDetached([Config.cmd.sh, "-c", `
            a=$(notify-send --urgency=critical --app-name=VPN --hint=string:x-raven-tag:vpn-ip \
                --action=copy="Copy $2" "VPN address changed" "$1 → $2 · payloads, LHOST and callbacks need the new one")
            [ "$a" = copy ] && exec "$3" -- "$2"`, "sh", before, after, Config.cmd.wlCopy]);
    }

    onActiveChanged: {
        if (active) {
            dropCheck.stop();
        } else if (wasActive && pending !== "down") {
            dropCheck.restart();
        }
        wasActive = active;
    }

    Timer {
        id: dropCheck
        interval: 4000
        onTriggered: if (!root.active && root.pending !== "down") root.alarm()
    }

    function alarm(): void {
        const what = (root.hasProfile ? root.profile : root.lastName) + (root.lastIp ? " · " + root.lastIp : "");
        Quickshell.execDetached([Config.cmd.sh, "-c", `
            m="\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/raven-vpn-down"
            [ -n "$(find "$m" -newermt "90 seconds ago" 2>/dev/null)" ] && exit 0
            if [ "$2" = 1 ]; then
                a=$(notify-send --urgency=critical --app-name=VPN --hint=string:x-raven-tag:vpn \
                    --action=reconnect=Reconnect "VPN dropped" "$1 is gone")
                [ "$a" = reconnect ] && exec "$3" up
            else
                notify-send --urgency=critical --app-name=VPN --hint=string:x-raven-tag:vpn "VPN dropped" "$1 is gone"
            fi`, "sh", what, root.hasProfile && !root.manual ? "1" : "0", root.helper]);
    }

    function readProfile(text: string): void {
        let st;
        try {
            st = JSON.parse(text);
        } catch (e) {
            return;
        }
        root.profile = st.profile ?? "";
        root.profileState = st.state ?? "none";
        root.manual = !!st.manual;
        if (st.error) {
            root.error = st.error;
            clearError.restart();
        }
    }

    function parse(text: string): void {
        let all;
        try {
            all = JSON.parse(text);
        } catch (e) {
            return;
        }
        const found = [];
        for (const link of all) {
            if (!root.pattern.test(link.ifname ?? "") || link.operstate === "DOWN")
                continue;
            const inet = (link.addr_info ?? []).find(a => a.family === "inet");
            if (inet)
                found.push({ name: link.ifname, ip: inet.local, prefix: inet.prefixlen });
        }
        found.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));
        if (JSON.stringify(found) !== JSON.stringify(root.tunnels))
            root.tunnels = found;
    }

    // ---- Pivots: tun / WireGuard interfaces used to reach internal networks (ligolo-ng and the
    // like). A pivot is an interface of that kind that is up with no IPv4 of its own (ligolo's has
    // none), or one named like ligolo/pivot. Shown with the networks routed through it and, while
    // ligolo-proxy runs, its agents (established connections). Up = carrier on and, if
    // ligolo-proxy runs, at least one agent connected. One that was up and stays down 4 s ->
    // critical "Pivot dropped" notification (not when ligolo-proxy itself was quit).
    property var pivots: []             // [{ name, routes: [cidr], up, agents: [ip] }]
    property var pivotUp: ({})          // name -> was up at the last read
    property var pivotLost: ({})        // name -> routes, waiting to be announced
    readonly property var pivotName: /(ligolo|pivot|^lig|^ttun)/

    function parsePivots(text: string): void {
        const parts = text.split("#ROUTES");
        const rest = (parts[1] ?? "").split("#AGENTS");
        let links, routes;
        try {
            links = JSON.parse(parts[0]);
            routes = JSON.parse(rest[0]);
        } catch (e) {
            return;
        }
        const agents = [];
        let ligolo = false;             // ligolo-proxy is running
        for (const line of (rest[1] ?? "").split("\n")) {
            if (line.indexOf("ligolo") < 0) continue;
            ligolo = true;
            const cols = line.trim().split(/\s+/);
            if (cols.length >= 4 && cols[0] !== "LISTEN") {
                const peer = cols[3].replace(/^\[?(::ffff:)?/, "").replace(/\]?:\d+$/, "");
                if (peer && agents.indexOf(peer) < 0) agents.push(peer);
            }
        }
        const found = [];
        for (const link of links) {
            const kind = link.linkinfo?.info_kind ?? "";
            const flags = link.flags ?? [];
            if (kind !== "tun" && kind !== "wireguard") continue;
            const named = root.pivotName.test(link.ifname);
            const hasIp = root.tunnels.some(t => t.name === link.ifname);
            if (hasIp && !named) continue;                      // the VPN itself
            if (!named && flags.indexOf("UP") < 0) continue;
            const via = routes.filter(r => r.dev === link.ifname && r.dst && r.dst !== "default")
                              .map(r => r.dst.indexOf("/") < 0 ? r.dst + "/32" : r.dst);
            if (!named && via.length === 0) continue;
            const carrier = flags.indexOf("UP") >= 0 && flags.indexOf("LOWER_UP") >= 0;
            found.push({ name: link.ifname, routes: via, up: carrier && (!ligolo || agents.length > 0),
                         agents: ligolo ? agents : [] });
        }
        found.sort((a, b) => a.name.localeCompare(b.name));
        if (JSON.stringify(found) !== JSON.stringify(root.pivots))
            root.pivots = found;

        const now = {};
        for (const p of found) now[p.name] = p.up;
        const lost = Object.assign({}, root.pivotLost);
        for (const name in root.pivotUp) {
            // ligolo-proxy quit (by you, usually): its interface going down is expected, no alarm.
            if (root.pivotUp[name] && !now[name] && (ligolo || !/ligolo|^lig/.test(name))) {
                const was = found.find(p => p.name === name);
                lost[name] = { routes: was ? was.routes : (root.lastPivotRoutes[name] ?? []), at: Date.now() };
            }
        }
        for (const name in now)
            if (now[name]) delete lost[name];
        for (const p of found)
            if (p.routes.length) root.lastPivotRoutes[p.name] = p.routes;
        root.pivotLost = lost;
        root.pivotUp = now;
        for (const name in lost) {
            if (Date.now() - lost[name].at >= 4000) {
                root.pivotAlarm(name, lost[name].routes);
                delete lost[name];
                root.pivotLost = lost;
            }
        }
    }
    property var lastPivotRoutes: ({})

    function pivotAlarm(name: string, routes: var): void {
        const nets = routes.length ? routes.join(", ") : "its networks";
        Quickshell.execDetached(["notify-send", "--urgency=critical", "--app-name=Pivot",
                                 "--hint=string:x-raven-tag:pivot", "Pivot dropped",
                                 name + " is down · " + nets + " unreachable"]);
    }

    Process {
        id: pivotReader
        command: [Config.cmd.sh, "-c", "ip -d -j link show; echo '#ROUTES'; ip -j -4 route show; echo '#AGENTS'; ss -Htnp state established 2>/dev/null | grep ligolo; pgrep -x ligolo-proxy >/dev/null && echo ligolo-proxy-running"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePivots(text)
        }
    }

    Process {
        id: reader
        command: [Config.cmd.ip, "-j", "-4", "addr", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: stats
        command: [Config.cmd.sh, "-c", 'cat "/sys/class/net/$1/statistics/rx_bytes" "/sys/class/net/$1/statistics/tx_bytes" && stat -c %Z "/sys/class/net/$1"', "sh", root.name]
        stdout: StdioCollector {
            onStreamFinished: root.readStats(text)
        }
    }

    Process {
        id: profileReader
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.readProfile(text)
        }
    }

    Process {
        id: action
        stdout: StdioCollector {
            onStreamFinished: root.readProfile(text)
        }
        onExited: {
            root.pending = "";
            if (!reader.running) reader.running = true;
        }
    }

    Timer {
        id: clearError
        interval: 8000
        onTriggered: root.error = ""
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now() / 1000;
            if (!reader.running) reader.running = true;
            if (!pivotReader.running) pivotReader.running = true;
            if (root.active && !stats.running) stats.running = true;
            if (!action.running && !profileReader.running) profileReader.running = true;
        }
    }

    Timer {
        id: settle
        interval: 1600
        onTriggered: root.copied = ""
    }
}
