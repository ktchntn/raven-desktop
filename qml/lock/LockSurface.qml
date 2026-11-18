import QtQuick
import qs.theme
import qs.services

// RAVEN: what each locked screen shows. Dot rain (shaders/rain.frag) behind the same box the
// old hyprlock lock had: dot-matrix clock, date, password field that lights up lime.
Item {
    id: root

    ShaderEffect {
        id: rain
        anchors.fill: parent

        property real time: 0
        readonly property real started: Date.now()      // a surface is made each time the screen locks
        property real pitch: 12
        property size size: Qt.size(width, height)
        property color accent: Tokens.accent
        property color ink: Tokens.ink
        property color grid: Tokens.off

        fragmentShader: Qt.resolvedUrl("../shaders/rain.frag.qsb")

        Timer {
            interval: 33
            repeat: true
            running: Lock.locked
            onTriggered: rain.time = (Date.now() - rain.started) / 1000
        }
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10
        width: 420
        height: 280
        radius: 22
        color: Tokens.black
        border.width: 1
        border.color: Tokens.line

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                color: Tokens.ink
                font.family: Tokens.fontDot
                font.weight: Font.Black
                font.pixelSize: 64
                text: Qt.formatTime(new Date(), "h:mm AP")

                Timer {
                    interval: 1000
                    repeat: true
                    running: Lock.locked
                    triggeredOnStart: true
                    onTriggered: {
                        const now = new Date();
                        clock.text = Qt.formatTime(now, "h:mm AP");
                        date.text = Qt.formatDate(now, "dddd d MMMM");
                    }
                }
            }

            Text {
                id: date
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 12
                bottomPadding: 30
                color: Tokens.dim
                font.family: Tokens.fontMono
                font.pixelSize: 15
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340
                height: 46
                radius: 10
                color: Tokens.surface
                border.width: 1
                border.color: Lock.checking || Lock.error !== "" ? Tokens.accent : Tokens.line

                Behavior on border.color { ColorAnimation { duration: Tokens.animFast } }

                Text {
                    anchors.centerIn: parent
                    visible: Lock.buffer === ""
                    text: Lock.checking ? "Checking…" : Lock.error !== "" ? Lock.error : "Password"
                    color: Lock.error !== "" || Lock.checking ? Tokens.accent : Tokens.muted
                    font.family: Tokens.fontMono
                    font.pixelSize: 14
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: Lock.buffer !== ""

                    Repeater {
                        model: Math.min(Lock.buffer.length, 24)

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: Lock.checking ? Tokens.accent : Tokens.ink
                        }
                    }
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "●"
            color: Tokens.accent
            font.family: Tokens.fontIcons
            font.pixelSize: 10
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "nevermore"
            color: Tokens.off
            font.family: Tokens.fontMono
            font.italic: true
            font.pixelSize: 13
        }
    }

    // Typing goes straight to the field (there is nothing else to focus).
    Item {
        anchors.fill: parent
        focus: true

        Component.onCompleted: console.info("lock: surface ready, keyboard focus=" + activeFocus)
        onActiveFocusChanged: console.info("lock: surface keyboard focus=" + activeFocus)

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Lock.submit();
            } else if (event.key === Qt.Key_Backspace) {
                Lock.erase((event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) !== 0);
            } else if (event.key === Qt.Key_Escape) {
                Lock.erase(true);
            } else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
                Lock.type(event.text);
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
