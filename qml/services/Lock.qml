pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// RAVEN: the lock screen's state and password check; the screens are lock/LockScreen.qml. The lock is in the shell (it replaced hyprlock as the first choice, 2026-11-16, so
// the background can animate: dot rain, shaders/rain.frag). Same look as the old hyprlock box.
//
//   raven-ipc lock lock      lock now (bin/lock-screen does this; ⌘K and hypridle call that)
//   raven-ipc lock secure    "true" once the compositor confirms every screen is covered
//
// The password is checked by PAM with hyprlock's service file (/etc/pam.d/hyprlock: common-auth).
// While locked, $XDG_RUNTIME_DIR/raven-locked exists; a restarted shell finds it and locks again
// (Hyprland's misc.allow_session_lock_restore lets a new client take over a lock).
Singleton {
    id: root

    property bool locked: false
    property string buffer: ""          // what's typed so far
    property bool checking: false
    property int failures: 0
    property string error: ""
    property bool secure: false          // set by lock/LockScreen.qml (WlSessionLock.secure)
    onSecureChanged: console.info("lock: secure=" + secure)
    onLockedChanged: console.info("lock: locked=" + locked)

    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/raven-locked"

    function lock(): void {
        if (locked) return;
        buffer = "";
        error = "";
        failures = 0;
        checking = false;
        locked = true;
        console.info("lock: locking");
        Quickshell.execDetached(["sh", "-c", ": > \"$1\"", "sh", marker]);
    }

    function type(text: string): void {
        if (checking) return;
        if (buffer === "") console.info("lock: typing started");   // never the characters
        error = "";
        buffer += text;
    }

    function erase(all: bool): void {
        if (checking) return;
        buffer = all ? "" : buffer.slice(0, -1);
    }

    function submit(): void {
        if (checking || buffer === "") return;
        checking = true;
        error = "";
        console.info("lock: checking password");
        if (!pam.start()) {
            checking = false;
            buffer = "";
            error = "Couldn't start the password check";
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"

        onPamMessage: {
            if (this.responseRequired) this.respond(root.buffer);
        }

        onCompleted: result => {
            root.checking = false;
            root.buffer = "";
            console.info("lock: password check " + PamResult.toString(result));
            if (result === PamResult.Success) {
                root.failures = 0;
                root.error = "";
                root.locked = false;
                Quickshell.execDetached(["rm", "-f", root.marker]);
            } else {
                root.failures++;
                root.error = "Wrong password (" + root.failures + ")";
            }
        }

        onError: error => {
            console.warn("lock: PAM error " + PamError.toString(error));
            root.checking = false;
            root.buffer = "";
            root.error = "Password check failed: " + PamError.toString(error);
        }
    }

    // Locked when the shell (re)started: lock again straight away.
    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: code => { if (code === 0) root.lock(); }
    }

    IpcHandler {
        target: "lock"

        function lock(): void { root.lock(); }
        function secure(): bool { return root.locked && root.secure; }
    }
}
