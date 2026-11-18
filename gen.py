#!/usr/bin/env python3
"""RAVEN shell generator.

Builds ~/.config/quickshell/raven from the upstream NIHIL Quickshell shell
(https://github.com/poligle/Nihil-Shell, MIT, (c) 2026 Pol Iglesias):
rebrands NIHIL -> RAVEN, applies the accent colour, and writes the files the
upstream Nix build generated (Tokens.qml, Config.qml, Lang.qml).
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys

MOTTO = "nevermore"


def trash(path):
    """Never delete outright: move an old copy to the Trash (trash-cli)."""
    if os.path.lexists(path):
        subprocess.run(["trash-put", path], check=True)


def rebrand(text):
    text = text.replace("ex nihilo", MOTTO)
    text = text.replace("NIHIL", "RAVEN").replace("Nihil", "Raven").replace("nihil", "raven")
    return text


# RAVEN's own wording (English), over upstream's theme/i18n.nix. Nilo runs on Claude Code here:
# its access toggles pick Claude Code's tools, and Claude Code runs read-only commands without asking.
STRING_OVERRIDES = {
    "accessSystemSub": "Read and search files on this computer",
    "accessWriteSub": "Create and change files (I work in %1), showing you each change first",
    "accessWriteGuard": "I'll be able to create and change files on this computer as your user, working in %1. Before each change I show you the diff, and nothing is touched until you confirm.",
    "accessGitSub": "Commit and push in %1 (with Terminal on), always asking you first",
    "accessGitGuard": "With Terminal on, I'll be able to commit and push in %1 as your git user. Each git command is shown to you first and waits for your confirmation.",
    "accessShellSub": "Run commands: anything beyond read-only ones is confirmed by you",
    "accessShellGuard": "I'll be able to run commands as your user on this computer. Read-only ones (ls, cat, grep...) run without asking; for anything else I show you the exact command, where it runs and what for, and nothing runs until you confirm.",
    "modelInstalled": "",
    "setRepo": "Working folder",
    # Huginn's example prompts (one per access toggle), about this machine instead of NixOS / Zen.
    "niloTryFlake": "Explain Kerberoasting in two lines",
    "niloTryNews": "What's new in the latest Kali release?",
    "niloTryDisk": "Summarize today's note in ~/Raven/Daily Notes",
    "niloTryShell": "What's listening on this machine?",
    "niloTryApps": "Open Wireshark",
    "niloTryFiles": "Save an nmap cheat sheet to ~/Notes",
    "niloTryPush": "Commit the changes in my working folder",
}


STRING_RENAMES = [("Nilo", "Huginn")]


def parse_i18n(path, lang):
    """Read one language block of theme/i18n.nix: lines of `key = "value";`."""
    strings, inside = {}, False
    for line in open(path, encoding="utf-8"):
        if re.match(r"^\t%s =\s*$" % lang, line):
            inside = True
            continue
        if inside and re.match(r"^\t};", line):
            break
        if inside:
            m = re.match(r'^\s*([A-Za-z0-9_]+) = "((?:[^"\\]|\\.)*)";', line)
            if m:
                value = m.group(2).replace('\\"', '"').replace("\\\\", "\\").replace("\\$", "$")
                strings[m.group(1)] = rebrand(value)
    if not strings:
        sys.exit(f"gen.py: no strings for language {lang!r} in {path}")
    return strings


# Accent patches: (file, old, new). Every `old` must exist, so upstream changes
# are noticed instead of silently skipped.
def accent_patches():
    return [
        # Lime is light: whatever sits on an accent fill is drawn in black, not ink.
        ("components/KeyButton.qml",
         "color: root.danger ? Tokens.ink : root.accent",
         "color: root.danger ? Tokens.black : root.accent"),
        ("drawers/Launcher.qml",
         "color: row.isArmed ? Tokens.ink : (row.modelData.danger",
         "color: row.isArmed ? Tokens.black : (row.modelData.danger"),
        ("drawers/Launcher.qml",
         "color: row.selected || row.isArmed ? Tokens.ink : Tokens.dim",
         "color: row.isArmed ? Tokens.black : row.selected ? Tokens.ink : Tokens.dim"),
        ("drawers/Launcher.qml",
         "color: row.isArmed ? Tokens.ink : Tokens.muted",
         "color: row.isArmed ? Tokens.black : Tokens.muted"),
        # The focused workspace LED glows in the accent.
        ("frame/Workspaces.qml",
         "color: slot.urgent ? Tokens.interrupt : (slot.isFocused || slot.occupied ? Tokens.ink : Tokens.off)",
         "color: slot.urgent ? Tokens.interrupt : (slot.isFocused ? Tokens.accent : slot.occupied ? Tokens.ink : Tokens.off)"),
        # Bar logo: the Kali dragon, lit in the accent on hover.
        ("frame/Bar.qml", "glyph: Icons.nix", "glyph: Icons.kali"),
        ("frame/Bar.qml",
         'color: logo.containsMouse || Drawers.isOpen("launcher", root.output) ? Tokens.ink : Tokens.dim',
         'color: logo.containsMouse || Drawers.isOpen("launcher", root.output) ? Tokens.accent : Tokens.ink'),
        # 12-hour time.
        ("services/Dates.qml", 'Qt.formatDateTime(date, "HH:mm")', 'Qt.formatDateTime(date, "h:mm AP")'),
        ("nilo/Settings.qml", '"HH:mm")', '"h:mm AP")'),
        ("frame/BarClock.qml", 'text: Qt.formatDateTime(clock.date, "HH")', 'text: Qt.formatDateTime(clock.date, "h AP").split(" ")[0]'),
        ("frame/BarClock.qml",
         '''            color: Tokens.dim
        }
    }''',
         '''            color: Tokens.dim
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 7
            text: Qt.formatDateTime(clock.date, "AP")
            font.family: Tokens.fontMono
            font.pixelSize: 9
            color: Tokens.muted
        }
    }'''),
        ("background/Desktop.qml",
         '''                DotText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.pixelSize: 84
                }''',
         '''                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    DotText {
                        id: deskTime
                        text: Qt.formatDateTime(clock.date, "h:mm AP").split(" ")[0]
                        font.pixelSize: 84
                    }
                    DotText {
                        anchors.baseline: deskTime.baseline
                        text: Qt.formatDateTime(clock.date, "AP")
                        font.pixelSize: 24
                        color: Tokens.dim
                    }
                }'''),
        ("drawers/Dashboard.qml",
         '''                DotText {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.pixelSize: 68
                }''',
         '''                Row {
                    spacing: 8
                    DotText {
                        id: dashTime
                        text: Qt.formatDateTime(clock.date, "h:mm AP").split(" ")[0]
                        font.pixelSize: 68
                    }
                    DotText {
                        anchors.baseline: dashTime.baseline
                        text: Qt.formatDateTime(clock.date, "AP")
                        font.pixelSize: 20
                        color: Tokens.dim
                    }
                }'''),
        # Warp is the terminal, but it cannot run a command (`-e`): terminal apps run in kitty.
        ("services/Apps.qml", '[Config.cmd.terminal, "-e"]', '[Config.cmd.terminalExec, "-e"]'),
        ("services/Nilo.qml", '[Config.cmd.terminal, "-e"', '[Config.cmd.terminalExec, "-e"'),
        ("settings/PagePhone.qml", '[Config.cmd.terminal, "--hold"', '[Config.cmd.terminalExec, "--hold"'),
        # Clipboard "browse" (SUPER + H): the history opens at once with the keyboard and
        # stays until Enter/Esc; letting go of SUPER does not paste (unlike holding SUPER + V).
        ("services/Clipboard.qml",
         "    property bool keyboard: false\n",
         "    property bool keyboard: false\n    property bool browsing: false\n"),
        ("services/Clipboard.qml",
         "    function reveal(): void {",
         '''    function browse(): void {
        if (phase !== "") {
            step(1);
            return;
        }
        if (!enabled)
            return;
        target = ToplevelManager.activeToplevel;
        index = 0;
        refresh();
        browsing = true;
        keyboard = true;
        reveal();
    }

    function reveal(): void {'''),
        ("services/Clipboard.qml",
         "    function released(from: string): void {\n",
         "    function released(from: string): void {\n        if (browsing)\n            return;\n"),
        ("services/Clipboard.qml",
         '''        phase = "";
        keyboard = false;''',
         '''        phase = "";
        keyboard = false;
        browsing = false;'''),
        ("services/Clipboard.qml",
         "        function open(): void { root.press(); }",
         "        function open(): void { root.press(); }\n        function browse(): void { root.browse(); }"),
        # History size follows Preferences > System (settings.json, saved by `raven apply`)
        # instead of the build-time Config.clipboard; raven-clipboard store reads the same key.
        ("services/Clipboard.qml",
         "    readonly property bool enabled: Config.clipboard > 0",
         "    readonly property int size: Machine.saved.clipboard ?? Config.clipboard\n"
         "    readonly property bool enabled: root.size > 0"),
        ("services/Clipboard.qml", "found.slice(0, Config.clipboard)", "found.slice(0, root.size)"),
        ("services/Clipboard.qml", '"list", String(Config.clipboard)]', '"list", String(root.size)]'),
        # VPN: while a tunnel is up, the bar shows a lime shield instead of the network icon,
        # and the dashboard / desktop widget show the VPN (1-click copy) instead of the media player;
        # with a raven-vpn profile the VPN card stays while down (1-click connect).
        ("frame/Status.qml",
         """            glyph: Network.ethernet ? Icons.ethernet""",
         """            glyph: Vpn.active ? Icons.vpn
                 : Network.ethernet ? Icons.ethernet"""),
        ("frame/Status.qml",
         "            color: Network.connected ? Tokens.ink : Tokens.muted",
         "            color: Vpn.active ? Tokens.accent : Network.connected ? Tokens.ink : Tokens.muted"),
        ("drawers/Dashboard.qml",
         """            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    DotScreen {
                        Layout.preferredWidth: 104""",
         """            ColumnLayout {
                visible: Vpn.shown || Listeners.any
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 10

                VpnCard {
                    visible: Vpn.shown
                    Layout.fillWidth: true
                    size: 40
                    showTraffic: true
                    scopeHeight: 26
                }

                Rectangle {
                    visible: Vpn.shown && Listeners.any
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Tokens.line
                }

                ListenersCard {
                    visible: Listeners.any
                    Layout.fillWidth: true
                    maxRows: Vpn.shown ? 2 : 6
                }

                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                visible: !(Vpn.shown || Listeners.any)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    DotScreen {
                        Layout.preferredWidth: 104"""),
        # Nilo runs on Claude Code (bin/raven-nilo) instead of a local Ollama model:
        # confirm cards for tools other than Bash/Edit/Write ("tool" action: Allow <tool>, its summary);
        ("nilo/Chat.qml",
         'readonly property bool command: facts.action === "run" || facts.action === "terminal"',
         'readonly property bool command: facts.action === "run" || facts.action === "terminal" || facts.action === "tool"'),
        ("nilo/Chat.qml",
         """                                : card.command ? Lang.confirmRun + (card.facts.action === "terminal" ? " " + Lang.confirmTerminal : "")""",
         """                                : card.facts.action === "tool" ? "Allow " + (card.facts.tool ?? "")
                                : card.command ? Lang.confirmRun + (card.facts.action === "terminal" ? " " + Lang.confirmTerminal : "")"""),
        # no local-model settings (auto fast/slow model, thinking, sleep after), no intro (it downloads a model),
        # and the hidden rows are out of the keyboard order.
        ("nilo/Settings.qml",
         """    readonly property int autoIndex: modelCount
    readonly property int thinkIndex: modelCount + 1
    readonly property int accessStart: modelCount + 2""",
         """    readonly property int autoIndex: -2
    readonly property int thinkIndex: -3
    readonly property int accessStart: modelCount"""),
        ("nilo/Settings.qml",
         """            SwitchRow {
                id: autoRow
""",
         """            SwitchRow {
                id: autoRow
                visible: false
"""),
        ("nilo/Settings.qml",
         """            SwitchRow {
                id: thinkRow
""",
         """            SwitchRow {
                id: thinkRow
                visible: false
"""),
        ("nilo/Settings.qml",
         "            Section { title: Lang.setMemory }",
         "            Section { title: Lang.setMemory; visible: false }"),
        ("nilo/Settings.qml",
         """            GearRow {
                width: content.width
                title: Lang.setSleepAfter""",
         """            GearRow {
                visible: false
                width: content.width
                title: Lang.setSleepAfter"""),
        ("nilo/Settings.qml",
         """                KeyButton {
                    text: Lang.setIntro""",
         """                KeyButton {
                    visible: false
                    text: Lang.setIntro"""),
        # Nilo is called Huginn in RAVEN (Odin's raven of thought). Visible names only: files, the IPC
        # target and settings keys stay "nilo". Strings are renamed in STRING_RENAMES.
        ("nilo/NiloView.qml", 'text: "Nilo"', 'text: "Huginn"'),
        ("services/Nilo.qml", '"--app-name=Nilo"', '"--app-name=Huginn"'),
        ("settings/PageSystem.qml", 'title: "Nilo"', 'title: "Huginn"'),
        # Hash-aware clipboard: entries that look like hashes / tickets / tokens (services/HashId.js)
        # get a lime "<format> · <hashcat mode>" chip; clicking it runs raven-hash save <id> (adds the
        # hash to ~/Loot/hashes/<mode>-<slug>.txt and copies the hashcat command).
        ("services/Clipboard.qml",
         "import qs.config\n",
         "import qs.config\nimport \"HashId.js\" as HashId\n"),
        ("services/Clipboard.qml",
         'found.push({ id: id, kind: kind, text: preview, format: "", mime: "", width: 0, height: 0, file: "" });',
         'found.push({ id: id, kind: kind, text: preview, format: "", mime: "", width: 0, height: 0, file: "",\n'
         '                             hash: kind === "text" ? HashId.identify(plain) : null });'),
        ("services/Clipboard.qml",
         "    function wipe(): void {",
         """    function crack(id: string): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/raven-hash", "save", id]);
    }

    function wipe(): void {"""),
        ("drawers/ClipboardView.qml",
         'font.family: row.kind === "colour" || row.kind === "image" ? Tokens.fontMono : Tokens.fontSans',
         'font.family: row.kind === "colour" || row.kind === "image" || row.modelData.hash ? Tokens.fontMono : Tokens.fontSans'),
        ("drawers/ClipboardView.qml",
         """                Ico {
                    glyph: Icons.close""",
         """                Rectangle {
                    visible: !!row.modelData.hash
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: chipText.implicitWidth + 16
                    radius: 11
                    color: chipArea.containsMouse ? Tokens.accent : "transparent"
                    border.width: 1
                    border.color: Tokens.accent

                    Behavior on color { ColorAnimation { duration: Tokens.animFast } }

                    Txt {
                        id: chipText
                        anchors.centerIn: parent
                        text: row.modelData.hash ? row.modelData.hash.label + " · " + (row.modelData.hash.mode >= 0 ? row.modelData.hash.mode : "john") : ""
                        font.family: Tokens.fontMono
                        font.pixelSize: 10
                        color: chipArea.containsMouse ? Tokens.black : Tokens.accent
                    }

                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Clipboard.crack(row.modelData.id)
                    }
                }

                Ico {
                    glyph: Icons.close"""),
        # Huginn "explain this" (SUPER + ALT + X -> bin/raven-explain -> ipc nilo analyse): the copied
        # output goes to Claude with a "what stands out, what next" prompt; the chat shows one short line.
        ("services/Nilo.qml",
         "    function stop(): void {",
         """    function analyse(text: string): void {
        const body = String(text ?? "").replace(/\\s+$/, "");
        if (!body.trim() || busy) return;
        const lines = body.split("\\n").length;
        messages.append({ kind: "user", text: "What stands out in this copied output? (" + lines + (lines === 1 ? " line)" : " lines)"),
                          done: true, name: "", status: "", info: "", cid: "" });
        busy = true;
        phase = "waiting";
        mood = "";
        send({ op: "ask", text: "Here is output I copied during an authorized lab or engagement. What stands out, "
               + "and what would you check or try next? Be brief: the 3 to 5 most promising leads, each with "
               + "why and the command to run.\\n\\n```\\n" + body + "\\n```" });
    }

    function stop(): void {"""),
        ("services/Nilo.qml",
         "        function ask(text: string): void {",
         """        function analyse(text: string): void {
            root.open();
            root.analyse(text);
        }
        function ask(text: string): void {"""),
        # Bar status column: no Bluetooth or speaker icon (user, 2026-11-16: the speaker sat right
        # above the battery gauge and read as a dead volume meter). Wheel-for-volume stays.
        ("frame/Status.qml",
         """        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: !Bt.enabled ? Icons.btOff : Bt.connected.length > 0 ? Icons.btConnected : Icons.btOn
            color: Bt.connected.length > 0 ? Tokens.ink : Tokens.muted
        }

        Ico {
            id: speaker
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: Icons.volume(Audio.volume, Audio.muted)
            color: Audio.muted ? Tokens.muted : Tokens.ink
        }
""", ""),
        # Quick settings: no Bluetooth tile (user, 2026-11-16): the VM has no Bluetooth adapter.
        # Its device list section is left in place, unreachable.
        ("drawers/Panel.qml",
         """                Tile {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: Bt.enabled ? Icons.btOn : Icons.btOff
                    label: Lang.tileBluetooth
                    active: Bt.enabled
                    expandable: true
                    expanded: root.expanded === "bt"
                    onToggled: Bt.setEnabled(!Bt.enabled)
                    onExpand: root.toggleSection("bt")
                }

""", ""),
        # Quick settings: no Night light tile (user, 2026-11-16): hyprsunset can't change this VM's
        # screen (virtio GPU, "no ctm prop support"), so it toggled nothing. Leaves 9 tiles, 3 rows.
        ("drawers/Panel.qml",
         """                Tile {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: Icons.night
                    label: Lang.tileNight
                    active: Toggles.night
                    onToggled: Toggles.night = !Toggles.night
                }

""", ""),
        # DotScope: a minimum full-scale value, so a quiet trace stays low instead of filling the
        # scope (the VPN card uses floor 16 B/s and 16 KB/s, so pings and shells show).
        ("components/DotScope.qml",
         "    property real floor: 512        // bytes/s mapped to the baseline\n",
         "    property real floor: 512        // bytes/s mapped to the baseline\n"
         "    property real minPeak: floor * 4   // RAVEN: full scale is at least this\n"),
        ("components/DotScope.qml",
         "Math.log(Math.max(peak, root.floor * 4) / root.floor)",
         "Math.log(Math.max(peak, root.minPeak, root.floor * 4) / root.floor)"),
        # Lock screen in the shell (lock/, services/Lock.qml): dot rain instead of hyprlock.
        ("shell.qml", "import qs.settings\n", "import qs.settings\nimport qs.lock\n"),
        ("shell.qml", "    Preferences {}\n", "    Preferences {}\n\n    LockScreen {}\n"),
        # Engagement logging (bin/raven-rec, services/Rec.qml): REC dot at the top of the bar's status
        # (lime and pulsing while a terminal is recorded, dim while only the switch is on) ...
        ("frame/Status.qml",
         """        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: Vpn.active ? Icons.vpn""",
         """        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Rec.active || Rec.auto
            glyph: Icons.record
            color: Rec.active ? Tokens.accent : Tokens.muted

            SequentialAnimation on opacity {
                running: Rec.active
                loops: Animation.Infinite
                onRunningChanged: if (!running) parent.opacity = 1
                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: Vpn.active ? Icons.vpn"""),
        # ... and quick settings' Log tile: on = new terminals are recorded; the arrow (or turning it on
        # with no engagement chosen) opens the engagement picker.
        ("drawers/Panel.qml",
         """                    onToggled: { Drawers.close(); Recorder.toggle(); }
                }
""",
         """                    onToggled: { Drawers.close(); Recorder.toggle(); }
                }

                Tile {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: Icons.terminal
                    label: Rec.active ? "Log · " + Rec.recording.length : "Log"
                    active: Rec.auto
                    expandable: true
                    expanded: root.expanded === "rec"
                    onToggled: Rec.auto || Rec.engagement !== "" ? Rec.toggle() : root.toggleSection("rec")
                    onExpand: root.toggleSection("rec")
                }
"""),
        ("drawers/Panel.qml",
         """            ColumnLayout {
                Layout.fillWidth: true
                visible: root.expanded === "wifi\"""",
         """            ColumnLayout {
                Layout.fillWidth: true
                visible: root.expanded === "rec"
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: Rec.auto ? "New terminals recorded into" : "Engagement" }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: Rec.active ? "● " + Rec.recording.length + (Rec.recording.length === 1 ? " recording" : " recording")
                            : Rec.auto ? "switch on" : "switch off"
                        color: Rec.active ? Tokens.accent : Tokens.muted
                    }
                }

                Repeater {
                    model: root.expanded === "rec" ? Rec.engagements : []

                    ListRow {
                        required property var modelData

                        glyph: Icons.terminal
                        title: modelData
                        detail: modelData === Rec.engagement ? Icons.check : ""
                        current: modelData === Rec.engagement
                        onClicked: Rec.use(modelData)
                    }
                }

                Label {
                    visible: Rec.engagements.length === 0
                    text: "Make a folder in ~/engagements to log into"
                }

                Label {
                    visible: Rec.active
                    Layout.topMargin: 6
                    text: "Recording now · tap to stop"
                }

                Repeater {
                    model: root.expanded === "rec" ? Rec.recording : []

                    ListRow {
                        required property var modelData

                        glyph: Icons.record
                        title: modelData.engagement + " · " + modelData.tty + (modelData.auto ? " · auto" : "")
                        detail: "since " + String(modelData.started).slice(11, 16)
                        current: true
                        onClicked: Rec.stop(modelData.pid)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.expanded === "wifi\""""),
        # Preferences > System: no Fingerprint toggle (a VM has no reader: Parallels doesn't pass
        # Touch ID through, and RAVEN doesn't set up fprintd). Stays false, so Apply asks for the password.
        ("settings/PageSystem.qml",
         """        Setting {
            title: Lang.cfgFingerprint
""",
         """        Setting {
            visible: false
            title: Lang.cfgFingerprint
"""),
        # Dashboard: no task board (user has real apps for that); the top row grows with its
        # content instead (VPN + 2 or more listeners overflowed the fixed 232 px onto the tasks).
        ("drawers/Dashboard.qml",
         """
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Tokens.line
        }

        TaskBoard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.active
        }
""",
         "\n"),
        ("drawers/Dashboard.qml",
         "            Layout.preferredHeight: 232",
         "            Layout.preferredHeight: Math.max(232, implicitHeight)"),
        # Desktop: two columns. Left: clock, network, media. Right (while there is something to
        # show): one card with the VPN and the listeners, as tall as the left column.
        ("background/Desktop.qml",
         """        implicitWidth: 320
        implicitHeight: column.implicitHeight""",
         """        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight"""),
        ("background/Desktop.qml",
         """            Card {
                visible: root.enabled("clock")
""",
         """            Row {
                spacing: 14

            Column {
                id: leftColumn
                spacing: 14

            Card {
                id: clockCard
                visible: root.enabled("clock")
"""),
        ("background/Desktop.qml",
         """            Card {
                visible: root.enabled("media")
""",
         """            Card {
                visible: root.enabled("media") && !Vpn.shown
"""),
        ("background/Desktop.qml",
         """                        CircleButton { glyph: Icons.next; size: 28; onClicked: Media.next() }
                    }
                }
            }
""",
         """                        CircleButton { glyph: Icons.next; size: 28; onClicked: Media.next() }
                    }
                }
            }
            }

            // One card for the engagement: VPN on top, listeners under it, as tall as the
            // left column (bottom edges line up), taller if there are many listeners.
            Card {
                visible: Vpn.shown || Listeners.any
                height: Math.max(implicitHeight, leftColumn.height)

                VpnCard {
                    visible: Vpn.shown
                    Layout.fillWidth: true
                    size: 30
                    showTraffic: true
                    radar: true
                }

                Rectangle {
                    visible: Vpn.shown
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    implicitHeight: 1
                    color: Tokens.line
                }

                ListenersCard {
                    visible: Vpn.shown || Listeners.any
                    Layout.fillWidth: true
                    maxRows: 8
                    showEmpty: true
                }
            }
            }
"""),
        ("drawers/Panel.qml",
         "                Label { text: Network.ssid || Network.ethernet || Lang.offline }",
         "                Label { text: Vpn.active ? \"VPN · \" + Vpn.name + \" · \" + Vpn.ip : (Network.ssid || Network.ethernet || Lang.offline); color: Vpn.active ? Tokens.accent : Tokens.muted }"),
        # Quick notes: "+" in the launcher (or SUPER + ALT + N). Enter saves a new note; down/up pick
        # a recent one, Enter edits it, Delete (twice) removes it; Esc backs out. File work is done
        # by raven-notes (atomic, line-checked, keeps deleted/old versions in ~/Notes/.deleted.md).
        ("drawers/Launcher.qml",
         'readonly property string mode: query.startsWith("?") ? "nilo"',
         'readonly property string mode: query.startsWith("+") ? "note" : query.startsWith("?") ? "nilo"'),
        ("drawers/Launcher.qml",
         """            input.text = Nilo.summon ? "?" : "";
            Nilo.summon = false;""",
         """            Notes.reset();
            input.text = Notes.summon ? "+ " : Nilo.summon ? "?" : "";
            Notes.summon = false;
            Nilo.summon = false;
            if (input.text.startsWith("+")) Notes.refresh();"""),
        ("drawers/Launcher.qml",
         """        else result = "";
""",
         """        else result = "";
        if (mode !== "note") {
            if (Notes.editing) Notes.reset();
        } else {
            Notes.selected = -1;
            Notes.armed = -1;
            if (query === "+" || query === "+ ") Notes.refresh();
        }
"""),
        ("drawers/Launcher.qml",
         """        if (mode === "nilo") niloView.accept(term);
""",
         """        if (mode === "note") {
            if (Notes.selected >= 0) {
                input.text = "+ " + Notes.beginEdit(Notes.selected);
                return;
            }
            if (Notes.editing) {
                Notes.saveEdit(term);
                Drawers.close();
                return;
            }
            if (term) {
                Notes.add(term);
                Drawers.close();
            }
            return;
        }
        if (mode === "nilo") niloView.accept(term);
"""),
        ("drawers/Launcher.qml",
         'glyph: root.mode === "calc" ? Icons.calculator',
         'glyph: root.mode === "note" ? Icons.note : root.mode === "calc" ? Icons.calculator'),
        ("drawers/Launcher.qml",
         ': root.mode === "nilo" ? Lang.nilo : Lang.calculator',
         ': root.mode === "nilo" ? Lang.nilo : root.mode === "note" ? (Notes.editing ? "Editing" : "Note") : Lang.calculator'),
        ("drawers/Launcher.qml",
         ': Config.nilo.enabled ? Lang.hintAppsNilo : Lang.hintApps',
         """: root.mode === "note" ? (Notes.selected >= 0 ? "[Enter] Edit|[Del] Delete|[↑] Back up|[Esc] Cancel"
                : Notes.editing ? "[Enter] Save the change|[Esc] Cancel the edit" : "[Enter] Save|[↓] Pick a note|[Esc] Close")
            : (Config.nilo.enabled ? Lang.hintAppsNilo : Lang.hintApps).replace("|[Esc]", "|[+] Note|[Esc]")"""),
        ("drawers/Launcher.qml",
         "            Keys.onEscapePressed: if (!(root.niloMode && niloView.back())) Drawers.close()",
         """            Keys.onEscapePressed: {
                if (root.mode === "note" && (Notes.editing || Notes.selected >= 0)) {
                    Notes.reset();
                    input.text = "+ ";
                } else if (!(root.niloMode && niloView.back())) {
                    Drawers.close();
                }
            }"""),
        ("drawers/Launcher.qml",
         """            Keys.onPressed: event => {
                if (Drawers.byHover""",
         """            Keys.onPressed: event => {
                if (root.mode === "note" && !Notes.editing) {
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        Notes.step(event.key === Qt.Key_Down ? 1 : -1);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Delete && Notes.selected >= 0) {
                        Notes.remove(Notes.selected);
                        event.accepted = true;
                        return;
                    }
                }
                if (Drawers.byHover"""),
        ("drawers/Launcher.qml",
         """    KeyHints {
        id: footer""",
         """    Column {
        anchors.top: grid.top
        anchors.topMargin: 6
        anchors.left: grid.left
        anchors.right: grid.right
        visible: root.mode === "note"
        spacing: 4

        Label {
            bottomPadding: 6
            text: Notes.editing ? "Editing the note from " + Notes.editing.stamp + "  ·  Enter saves, Esc cancels"
                : "Saved to " + Notes.shown + "  ·  ↓ to pick a note to edit or delete"
            color: Notes.editing ? Tokens.accent : Tokens.muted
        }

        Repeater {
            model: Notes.recent

            Item {
                id: note
                required property var modelData
                required property int index
                readonly property bool picked: Notes.selected === index
                readonly property bool beingEdited: Notes.editing !== null && Notes.editing.n === modelData.n
                readonly property bool armed: Notes.armed === index

                width: parent.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: note.picked || noteHover.containsMouse ? Tokens.raised : "transparent"
                    border.width: note.beingEdited || note.armed ? 1 : 0
                    border.color: Tokens.accent
                }

                MouseArea {
                    id: noteHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Notes.selected = note.index;
                        Notes.armed = -1;
                        input.forceActiveFocus();
                    }
                }

                Txt {
                    id: stamp
                    x: 10
                    width: 92
                    anchors.verticalCenter: parent.verticalCenter
                    text: note.modelData.stamp.slice(5)
                    color: Tokens.muted
                    font.family: Tokens.fontMono
                    font.pixelSize: 12
                }

                Txt {
                    anchors.left: stamp.right
                    anchors.right: tools.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: note.armed ? "Delete this note? Press Delete or click the bin again" : note.modelData.body
                    color: note.armed ? Tokens.accent : Tokens.ink
                    font.family: Tokens.fontMono
                    font.pixelSize: 12
                }

                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    opacity: note.picked || noteHover.containsMouse || note.armed || editArea.containsMouse || binArea.containsMouse ? 1 : 0

                    Ico {
                        glyph: Icons.note
                        font.pixelSize: 14
                        color: editArea.containsMouse ? Tokens.accent : Tokens.dim

                        MouseArea {
                            id: editArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                input.text = "+ " + Notes.beginEdit(note.index);
                                input.forceActiveFocus();
                            }
                        }
                    }

                    Ico {
                        glyph: Icons.trash
                        font.pixelSize: 14
                        color: note.armed || binArea.containsMouse ? Tokens.accent : Tokens.dim

                        MouseArea {
                            id: binArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Notes.remove(note.index);
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        Label {
            visible: Notes.recent.length === 0
            text: "No notes yet"
            color: Tokens.muted
        }
    }

    KeyHints {
        id: footer"""),
        ("theme/Icons.qml",
         "readonly property string nix: g(0xF1105)",
         "readonly property string nix: g(0xF1105)\n    readonly property string kali: g(0xF327)\n    readonly property string vpn: g(0xF099D)\n    readonly property string note: g(0xF03EB)\n    readonly property string trash: g(0xF09E7)"),
        # Quick settings: Burp tile (services/Burp.qml, bin/raven-burp) after Log. On = both
        # browsers through Burp; "Burp · not running" when the proxy is on but nothing listens.
        ("drawers/Panel.qml",
         """                    onToggled: Rec.auto || Rec.engagement !== "" ? Rec.toggle() : root.toggleSection("rec")
                    onExpand: root.toggleSection("rec")
                }
""",
         """                    onToggled: Rec.auto || Rec.engagement !== "" ? Rec.toggle() : root.toggleSection("rec")
                    onExpand: root.toggleSection("rec")
                }

                Tile {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\\uf188"
                    label: Burp.proxy && !Burp.listening ? "Burp · not running" : "Burp"
                    active: Burp.proxy
                    onToggled: Burp.toggle()
                }
"""),
        # Bar: lime clock while the clock is on a domain controller's time (`dctime`, DcTime.qml).
        ("frame/Status.qml",
         """        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: Vpn.active ? Icons.vpn""",
         """        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: DcTime.active
            glyph: "\\uf017"
            color: Tokens.accent
        }

        Ico {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: Vpn.active ? Icons.vpn"""),
        # Huginn opened by its key (⌘⌥/) or the bar: Huginn mode without a "?" in the field
        # ("asking"); typing "?" in the launcher still works the old way. Backspace on an empty
        # field leaves Huginn for the app search.
        ("drawers/Launcher.qml",
         """    readonly property string mode: query.startsWith("+") ? "note" : query.startsWith("?") ? "nilo\"""",
         """    property bool asking: false
    readonly property string mode: asking ? "nilo" : query.startsWith("+") ? "note" : query.startsWith("?") ? "nilo\""""),
        ("drawers/Launcher.qml",
         """    readonly property string term: mode === "apps" ? query : query.slice(1).trim()""",
         """    readonly property string term: mode === "apps" ? query : asking ? query.trim() : query.slice(1).trim()"""),
        ("drawers/Launcher.qml",
         """            input.text = Notes.summon ? "+ " : Nilo.summon ? "?" : "";""",
         """            root.asking = !Notes.summon && Nilo.summon;
            input.text = Notes.summon ? "+ " : "";"""),
        ("drawers/Launcher.qml",
         """            if (!root.niloMode) input.text = "?";""",
         """            if (!root.niloMode) { root.asking = true; input.text = ""; }"""),
        ("drawers/Launcher.qml",
         """        if (query.startsWith("?") && query.slice(1).trim() !== "") Nilo.warm();""",
         """        if (root.niloMode && root.term !== "") Nilo.warm();"""),
        ("drawers/Launcher.qml",
         """        onCleared: input.text = "?\"""",
         """        onCleared: input.text = root.asking ? "" : "?\""""),
        ("drawers/Launcher.qml",
         """                visible: input.text === "?" && niloView.view === "chat\"""",
         """                visible: (input.text === "?" || (root.asking && input.text === "")) && niloView.view === "chat\""""),
        ("drawers/Launcher.qml",
         """            placeholderText: Lang.search
""",
         """            placeholderText: root.asking ? "" : Lang.search
"""),
        ("drawers/Launcher.qml",
         """                x: input.leftPadding + mark.advanceWidth + 10""",
         """                x: input.leftPadding + (root.asking ? 0 : mark.advanceWidth + 10)"""),
        ("drawers/Launcher.qml",
         """                if (Drawers.byHover && !root.modifierOnly(event.key)) Drawers.byHover = false;""",
         """                if (root.asking && event.key === Qt.Key_Backspace && input.text === "") {
                    root.asking = false;
                    event.accepted = true;
                    return;
                }
                if (Drawers.byHover && !root.modifierOnly(event.key)) Drawers.byHover = false;"""),
    ]


LOGO_FACE = '''    readonly property var face: ({
        R: ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        A: [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        V: ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        E: ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        N: ["#...#", "##..#", "##..#", "#.#.#", "#..##", "#..##", "#...#"]
    })'''


def tokens_qml(t):
    p = t["palette"]
    return f'''pragma Singleton

import QtQuick
import Quickshell

// Generated by raven/gen.py: edit tokens.json there and rebuild.
Singleton {{
    readonly property color black: "#{p['void']}"
    readonly property color surface: "#{p['surface']}"
    readonly property color raised: "#{p['raised']}"
    readonly property color line: "#{p['line']}"
    readonly property color off: "#{p['off']}"
    readonly property color muted: "#{p['muted']}"
    readonly property color dim: "#{p['dim']}"
    readonly property color ink: "#{p['ink']}"
    readonly property color interrupt: "#{p['accent']}"
    readonly property color accent: "#{p['accent']}"

    readonly property string fontDot: Qt.fontFamilies().indexOf("{t['fonts']['dot']}") >= 0 ? "{t['fonts']['dot']}" : "{t['fonts']['mono']}"
    readonly property string fontSans: "{t['fonts']['sans']}"
    readonly property string fontMono: "{t['fonts']['mono']}"
    readonly property string fontIcons: "{t['fonts']['icons']}"

    readonly property int frameThickness: {t['frame']['thickness']}
    readonly property int barWidth: {t['frame']['bar']}
    readonly property int frameRadius: {t['frame']['radius']}
    readonly property int fillet: {t['frame']['fillet']}
    readonly property int drawerRadius: {t['frame']['drawerRadius']}

    readonly property int animFast: {t['motion']['fast']}
    readonly property int animNormal: {t['motion']['normal']}
    readonly property int animDrawer: {t['motion']['drawer']}
    readonly property int animSlow: {t['motion']['slow']}
}}
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="upstream repo checkout")
    ap.add_argument("--out", required=True, help="quickshell config dir to write")
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--config", required=True, help="JSON with Config.qml values")
    ap.add_argument("--shaders", required=True, help="dir of compiled .qsb shaders")
    ap.add_argument("--icon-theme", default="Papirus-Dark")
    ap.add_argument("--lang", default="en")
    a = ap.parse_args()

    tokens = json.load(open(a.tokens))
    config = json.load(open(a.config))

    # Skip the build when nothing that goes into it has changed (keeps re-runs quiet and
    # avoids sending an identical old copy to the Trash).
    import hashlib
    import subprocess
    here = os.path.dirname(os.path.abspath(__file__))
    h = hashlib.sha256()
    head = subprocess.run(["git", "-C", a.src, "rev-parse", "HEAD"], capture_output=True, text=True).stdout
    h.update(head.encode())
    inputs = [os.path.abspath(__file__), a.tokens, a.config]
    for root_dir in (os.path.join(here, "qml"), a.shaders):
        for dirpath, _, names in sorted(os.walk(root_dir)):
            inputs += [os.path.join(dirpath, n) for n in sorted(names)]
    for path in inputs:
        h.update(path.encode())
        h.update(open(path, "rb").read())
    h.update(f"{a.icon_theme}|{a.lang}".encode())
    stamp = h.hexdigest()
    stamp_file = os.path.join(a.out, ".raven-stamp")
    if os.path.exists(stamp_file) and open(stamp_file).read().strip() == stamp:
        print(f"gen.py: {a.out} is up to date")
        return
    shell = os.path.join(a.src, "home/shell")

    tmp = a.out + ".new"
    trash(tmp)
    shutil.copytree(shell, tmp, ignore=shutil.ignore_patterns("tests"))
    shutil.copy(os.path.join(a.src, "LICENSE"), os.path.join(tmp, "LICENSE"))

    for root, _, files in os.walk(tmp):
        for name in files:
            if not name.endswith((".qml", ".js")):
                continue
            path = os.path.join(root, name)
            text = open(path, encoding="utf-8").read()
            new = rebrand(text)
            if new != text:
                open(path, "w", encoding="utf-8").write(new)

    for rel, old, new in accent_patches():
        path = os.path.join(tmp, rel)
        text = open(path, encoding="utf-8").read()
        if old not in text:
            sys.exit(f"gen.py: patch target not found in {rel}: {old[:70]}...")
        open(path, "w", encoding="utf-8").write(text.replace(old, new))

    # Whole files RAVEN replaces (raven/qml/...): the upstream file must exist,
    # so a rename upstream is noticed.
    here = os.path.dirname(os.path.abspath(__file__))
    # Whole new files RAVEN adds: must not exist upstream (a clash would be silent otherwise).
    for rel, src in {"services/Vpn.qml": "qml/services/Vpn.qml",
                     "components/VpnCard.qml": "qml/components/VpnCard.qml",
                     "services/Lock.qml": "qml/services/Lock.qml",
                     "services/Burp.qml": "qml/services/Burp.qml",
                     "services/DcTime.qml": "qml/services/DcTime.qml",
                     "lock/LockScreen.qml": "qml/lock/LockScreen.qml",
                     "lock/LockSurface.qml": "qml/lock/LockSurface.qml",
                     "services/Listeners.qml": "qml/services/Listeners.qml",
                     "components/ListenersCard.qml": "qml/components/ListenersCard.qml",
                     "services/Notes.qml": "qml/services/Notes.qml",
                     "services/HashId.js": "qml/services/HashId.js",
                     "services/Rec.qml": "qml/services/Rec.qml"}.items():
        if os.path.exists(os.path.join(tmp, rel)):
            sys.exit(f"gen.py: {rel} now exists upstream; rename RAVEN's file")
        os.makedirs(os.path.dirname(os.path.join(tmp, rel)), exist_ok=True)
        shutil.copy(os.path.join(here, src), os.path.join(tmp, rel))

    for rel, src in {"settings/PageKeys.qml": "qml/PageKeys.qml",
                     "services/Brightness.qml": "qml/services/Brightness.qml"}.items():
        if not os.path.exists(os.path.join(tmp, rel)):
            sys.exit(f"gen.py: file to replace not found upstream: {rel}")
        shutil.copy(os.path.join(here, src), os.path.join(tmp, rel))

    logo = os.path.join(tmp, "settings/Logo.qml")
    text = open(logo, encoding="utf-8").read()
    text, n = re.subn(r"    readonly property var face: \(\{.*?\}\)", LOGO_FACE, text, flags=re.S)
    if n != 1 or 'const word = "RAVEN";' not in text:
        sys.exit("gen.py: could not rewrite the logo")
    open(logo, "w", encoding="utf-8").write(text)

    qml = os.path.join(tmp, "shell.qml")
    text = open(qml, encoding="utf-8").read()
    open(qml, "w", encoding="utf-8").write(text.replace("@ICON_THEME@", a.icon_theme))

    open(os.path.join(tmp, "theme/Tokens.qml"), "w").write(tokens_qml(tokens))

    os.makedirs(os.path.join(tmp, "config"), exist_ok=True)
    lines = ["pragma Singleton", "", "import Quickshell", "",
             "// Generated by raven/gen.py.", "Singleton {"]
    for key, value in config.items():
        if isinstance(value, dict) and set(value) == {"js", "type"}:
            lines.append(f"    readonly property {value['type']} {key}: {value['js']}")
            continue
        kind = {bool: "bool", int: "int", str: "string"}.get(type(value), "var")
        js = json.dumps(value)
        lines.append(f"    readonly property {kind} {key}: {'(' + js + ')' if kind == 'var' else js}")
    lines.append("}")
    open(os.path.join(tmp, "config/Config.qml"), "w").write("\n".join(lines) + "\n")

    strings = parse_i18n(os.path.join(a.src, "theme/i18n.nix"), a.lang)
    for key, value in STRING_OVERRIDES.items():
        if key not in strings:
            sys.exit(f"gen.py: string to override not found upstream: {key}")
        strings[key] = value
    for old, new in STRING_RENAMES:
        strings = {k: re.sub(r"\b" + old + r"\b", new, v) for k, v in strings.items()}
    lines = ["pragma Singleton", "", "import Quickshell", "",
             "// Generated by raven/gen.py from theme/i18n.nix.", "Singleton {"]
    lines += [f"    readonly property string {k}: {json.dumps(v, ensure_ascii=False)}" for k, v in strings.items()]
    lines.append("}")
    open(os.path.join(tmp, "config/Lang.qml"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

    for f in os.listdir(a.shaders):
        shutil.copy(os.path.join(a.shaders, f), os.path.join(tmp, "shaders", f))

    open(os.path.join(tmp, ".raven-stamp"), "w").write(stamp + "\n")
    trash(a.out)
    os.rename(tmp, a.out)
    print(f"gen.py: wrote {a.out} ({len(strings)} strings)")


if __name__ == "__main__":
    main()
