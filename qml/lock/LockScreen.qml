import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// RAVEN: one lock surface per screen while services/Lock.qml says locked.
Scope {
    WlSessionLock {
        id: session
        locked: Lock.locked
        onSecureChanged: Lock.secure = secure

        WlSessionLockSurface {
            color: "black"

            LockSurface {
                anchors.fill: parent
            }
        }
    }
}
