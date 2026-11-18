pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// RAVEN: quick notes. SUPER + ALT + N opens the launcher in note mode ("+ "). Notes live under
// "## Captured" in Obsidian's daily notes (since 2026-11-17); only ~/.local/bin/raven-notes touches
// them: it writes atomically, refuses to change a line that no longer matches, and keeps deleted
// and pre-edit notes in ~/Notes/.deleted.md. A note's `n` is "<daily note>:<line>".
Singleton {
    id: root

    property bool summon: false          // the launcher opens in note mode
    property var recent: []              // [{ n, line, stamp, body }], newest first
    property int selected: -1            // index in recent, -1 = the text field
    property var editing: null           // the note being edited, or null
    property int armed: -1               // index awaiting a second Delete
    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/raven-notes"
    readonly property string shown: "today's note in Obsidian"

    function capture(): void {
        root.summon = true;
        Drawers.open("launcher", "", false);
    }

    function reset(): void {
        root.selected = -1;
        root.editing = null;
        root.armed = -1;
    }

    // Commands queue up, so nothing is dropped while the helper is busy.
    property var queue: []

    function run(args: var): void {
        root.queue = root.queue.concat([args]);
        root.next();
    }

    function next(): void {
        if (worker.running || root.queue.length === 0)
            return;
        worker.command = [root.tool].concat(root.queue[0]);
        root.queue = root.queue.slice(1);
        worker.running = true;
    }

    function refresh(): void { root.run(["list"]); }

    function add(text: string): void {
        root.run(["add", text]);
        root.reset();
    }

    // Enter on a picked note, or the pencil: its text goes into the field to be edited.
    function beginEdit(index: int): string {
        const note = root.recent[index];
        if (!note)
            return "";
        root.editing = note;
        root.selected = -1;
        root.armed = -1;
        return note.body;
    }

    function saveEdit(text: string): void {
        if (root.editing && text.trim() !== "")
            root.run(["edit", String(root.editing.n), root.editing.line, text]);
        root.reset();
    }

    // First press arms, the second one deletes.
    function remove(index: int): void {
        const note = root.recent[index];
        if (!note)
            return;
        if (root.armed !== index) {
            root.armed = index;
            return;
        }
        root.run(["delete", String(note.n), note.line]);
        root.reset();
    }

    function step(by: int): void {
        root.armed = -1;
        root.selected = Math.max(-1, Math.min(root.recent.length - 1, root.selected + by));
    }

    Process {
        id: worker
        command: [root.tool, "list"]
        onRunningChanged: if (!running) root.next()
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.recent = JSON.parse(text).notes ?? [];
                } catch (e) {}
            }
        }
    }

    IpcHandler {
        target: "notes"

        function capture(): void { root.capture(); }
    }
}
