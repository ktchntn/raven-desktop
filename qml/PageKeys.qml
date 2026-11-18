import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.theme
import qs.config
import qs.components

// RAVEN: Preferences > Shortcuts. A live, read-only list of every Hyprland bind that has a
// description (`description = "Group | What it does"` in hyprland.lua), shown with Mac keys.
// Replaces NIHIL's editor, which rebuilt NixOS to apply changes.
Flickable {
    id: page

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property var groupOrder: ["Apps", "Shell", "Windows", "Scratchpad", "Workspaces", "Clipboard", "Capture", "Session", "Media"]
    property var groups: []
    property string problem: ""

    // Hyprland modmask bits, written in the Mac order: control, option, shift, command.
    function mods(mask: int): string {
        let s = "";
        if (mask & 4) s += "⌃";
        if (mask & 8) s += "⌥";
        if (mask & 1) s += "⇧";
        if (mask & 64) s += "⌘";
        return s;
    }

    function keyName(key: string): string {
        const names = {
            slash: "/", period: ".", backslash: "\\", bracketleft: "[", bracketright: "]",
            minus: "-", equal: "=", comma: ",", semicolon: ";", apostrophe: "'", grave: "`",
            left: "←", right: "→", up: "↑", down: "↓", Return: "Return", Tab: "Tab", Space: "Space",
            Escape: "Esc", PRINT: "Print Screen", Print: "Print Screen",
            "mouse:272": "drag", "mouse:273": "right-drag", "mouse:275": "Mouse back", "mouse:276": "Mouse forward",
        };
        if (key in names) return names[key];
        if (key.startsWith("XF86")) return "media key";
        return key.length === 1 ? key.toUpperCase() : key;
    }

    // One row per description: binds that share it are merged ("⌘ 1–0", "⇧⌘ ← → ↑ ↓").
    function combos(binds: var): string {
        const sameMods = binds.every(b => b.modmask === binds[0].modmask);
        const keys = binds.map(b => page.keyName(b.key)).filter((k, i, all) => all.indexOf(k) === i);
        if (sameMods && binds.length > 1) {
            const m = page.mods(binds[0].modmask);
            const digits = keys.every(k => /^[0-9]$/.test(k));
            const list = digits && keys.length >= 10 ? keys[0] + "–" + keys[keys.length - 1] : keys.join(" ");
            return (m ? m + " " : "") + list;
        }
        return binds.map(b => {
            const m = page.mods(b.modmask);
            return (m ? m + " " : "") + page.keyName(b.key);
        }).join("   ·   ");
    }

    function build(text: string): void {
        let all;
        try {
            all = JSON.parse(text);
        } catch (e) {
            page.problem = "Could not read the shortcuts from Hyprland.";
            return;
        }
        const byGroup = {};
        const rows = {};
        for (const b of all) {
            if (!b.has_description || b.submap !== "")
                continue;
            const cut = b.description.indexOf("|");
            const group = cut >= 0 ? b.description.slice(0, cut).trim() : "Other";
            const what = cut >= 0 ? b.description.slice(cut + 1).trim() : b.description.trim();
            const id = group + "|" + what;
            if (!(group in byGroup))
                byGroup[group] = [];
            if (!(id in rows)) {
                rows[id] = { what: what, binds: [] };
                byGroup[group].push(rows[id]);
            }
            rows[id].binds.push(b);
        }
        const names = page.groupOrder.filter(g => g in byGroup)
            .concat(Object.keys(byGroup).filter(g => page.groupOrder.indexOf(g) < 0));
        page.groups = names.map(g => ({
            name: g,
            rows: byGroup[g].map(r => ({ what: r.what, keys: page.combos(r.binds) }))
        }));
        page.problem = page.groups.length === 0 ? "No described shortcuts found." : "";
    }

    Process {
        id: reader
        command: [Config.cmd.hyprctl, "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: page.build(text)
        }
    }

    Component.onCompleted: reader.running = true
    onVisibleChanged: if (visible && !reader.running) reader.running = true

    ColumnLayout {
        id: column
        width: page.width
        spacing: 0

        Heading {
            Layout.bottomMargin: 6
            title: Lang.cfgKeys
            sub: "Everything bound right now, read live from Hyprland. ⌘ is Command (Super), ⌥ is Option (Alt), ⇧ is Shift."
        }

        Txt {
            visible: page.problem !== ""
            Layout.topMargin: 12
            text: page.problem
            color: Tokens.muted
        }

        Repeater {
            model: page.groups

            ColumnLayout {
                id: group
                required property var modelData

                Layout.fillWidth: true
                Layout.topMargin: 18
                spacing: 0

                Label {
                    Layout.bottomMargin: 6
                    text: group.modelData.name
                }

                Repeater {
                    model: group.modelData.rows

                    Item {
                        id: row
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 38

                        Surface {
                            anchors.fill: parent
                            radius: 10
                            color: hover.containsMouse ? Tokens.surface : "transparent"
                        }

                        Txt {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: keys.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.what
                            color: Tokens.dim
                            elide: Text.ElideRight
                        }

                        Txt {
                            id: keys
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.keys
                            color: Tokens.ink
                            font.family: Tokens.fontMono
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
