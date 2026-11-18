import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services

// RAVEN: the VPN in place of the media player (dashboard and desktop widget).
// The address is one click to copy. With a raven-vpn profile the card stays while the VPN is
// down: one click on Connect brings it up, the power button in the header takes it down.
Item {
    id: root

    property int size: 30          // pixel size of the address, in dots
    property bool showTraffic: false   // tun0 traffic and its dot scope
    property int scopeHeight: 40
    property bool radar: false     // desktop: dot-grid radar sweep behind the card while the VPN is up
    // How far the radar reaches past this item, to the edges of the card around it.
    property real radarMarginX: 22
    property real radarMarginY: 20

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ShaderEffect {
        id: sweep
        visible: root.radar && Vpn.active
        x: -root.radarMarginX
        y: -root.radarMarginY
        width: root.width + 2 * root.radarMarginX
        height: root.height + 2 * root.radarMarginY

        property real angle: 0
        property real spacing: 11
        property real edge: 26
        property size size: Qt.size(width, height)
        property point centre: Qt.point(root.radarMarginX + ipRow.x + Math.min(address.contentWidth, ipRow.width) / 2,
                                        root.radarMarginY + ipRow.y + ipRow.height / 2)
        property color accent: Tokens.accent
        property color grid: Tokens.off

        fragmentShader: Qt.resolvedUrl("../shaders/radar.frag.qsb")

        // ~30 fps is plenty for a slow sweep and keeps the VM's GPU quiet; one turn per 5.2 s.
        Timer {
            interval: 33
            repeat: true
            running: sweep.visible
            onTriggered: sweep.angle = (Date.now() % 5200) / 5200 * 6.2831853
        }
    }

    ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Ico {
            glyph: Icons.vpn
            color: Vpn.active ? Tokens.accent : Tokens.muted
            font.pixelSize: 16
        }

        Label { text: "VPN" }

        Item { Layout.fillWidth: true }

        Label {
            text: Vpn.active ? Vpn.name : Vpn.busy ? "connecting" : "off"
            color: Vpn.active ? Tokens.ink : Vpn.busy ? Tokens.accent : Tokens.muted
        }

        Label {
            visible: Vpn.active && Vpn.uptime !== ""
            text: "· " + Vpn.uptime
        }

        CircleButton {
            visible: Vpn.active && (Vpn.canDisconnect || Vpn.pending === "down")
            size: 24
            glyph: Vpn.pending === "down" ? Icons.refresh : Icons.power
            label: "Disconnect " + Vpn.profile
            onClicked: Vpn.disconnect()
        }
    }

    // Down: the profile's name, and one click to connect.
    DotText {
        visible: !Vpn.active
        Layout.fillWidth: true
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 12
        text: Vpn.profile
        font.pixelSize: root.size
        color: connect.containsMouse && Vpn.canConnect ? Tokens.ink : Tokens.muted

        Behavior on color { ColorAnimation { duration: Tokens.animFast } }
    }

    Rectangle {
        visible: !Vpn.active
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 17
        color: connect.containsMouse && Vpn.canConnect ? Tokens.accent : "transparent"
        border.width: 1
        border.color: Vpn.canConnect || Vpn.busy ? Tokens.accent : Tokens.line

        Behavior on color { ColorAnimation { duration: Tokens.animFast } }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Ico {
                anchors.verticalCenter: parent.verticalCenter
                glyph: Vpn.busy ? Icons.refresh : Icons.power
                font.pixelSize: 15
                color: connect.containsMouse && Vpn.canConnect ? Tokens.black : Vpn.canConnect || Vpn.busy ? Tokens.accent : Tokens.muted
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Vpn.busy ? "Connecting…" : Vpn.manual ? "Manual openvpn running" : "Connect"
                font.pixelSize: 13
                color: connect.containsMouse && Vpn.canConnect ? Tokens.black : Vpn.canConnect || Vpn.busy ? Tokens.accent : Tokens.muted
            }
        }

        MouseArea {
            id: connect
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Vpn.canConnect ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Vpn.connect()
        }
    }

    Label {
        visible: Vpn.error !== ""
        Layout.fillWidth: true
        text: Vpn.error
        color: Tokens.dim
        wrapMode: Text.Wrap
    }

    Item {
        id: ipRow
        visible: Vpn.active
        Layout.fillWidth: true
        implicitHeight: address.implicitHeight

        DotText {
            id: address
            // Shrinks to fit the space it has, so a long address never runs into its neighbours.
            width: parent.width - 30
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
            text: Vpn.ip
            font.pixelSize: root.size
            color: main.containsMouse || Vpn.copied === Vpn.ip ? Tokens.accent : Tokens.ink

            Behavior on color { ColorAnimation { duration: Tokens.animFast } }
        }

        Ico {
            x: address.contentWidth + 12
            anchors.verticalCenter: address.verticalCenter
            glyph: Vpn.copied === Vpn.ip ? Icons.check : Icons.copy
            font.pixelSize: 15
            color: Vpn.copied === Vpn.ip ? Tokens.accent : main.containsMouse ? Tokens.ink : Tokens.muted
        }

        MouseArea {
            id: main
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Vpn.copy(Vpn.ip)
        }
    }

    RowLayout {
        visible: root.showTraffic && Vpn.active
        Layout.fillWidth: true
        Layout.topMargin: 6

        Label { text: "Traffic" }
        Item { Layout.fillWidth: true }
        Label { text: "↓ " + SysStats.human(Vpn.rx); color: Tokens.dim }
        Label { text: "↑ " + SysStats.human(Vpn.tx) }
    }

    DotScope {
        visible: root.showTraffic && Vpn.active
        Layout.fillWidth: true
        Layout.preferredHeight: root.scopeHeight
        series: Vpn.rxHistory
        secondary: Vpn.txHistory
        floor: 16           // VPN traffic is often tiny (pings, a shell); show it
        minPeak: 16384
    }

    // Any further tunnels, smaller, each one click to copy.
    Repeater {
        model: Vpn.tunnels.slice(1)

        Item {
            id: extra
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 22

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: extra.modelData.name
            }

            Txt {
                anchors.right: mark.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: extra.modelData.ip
                font.family: Tokens.fontMono
                font.pixelSize: 12
                color: hover.containsMouse || Vpn.copied === extra.modelData.ip ? Tokens.accent : Tokens.ink
            }

            Ico {
                id: mark
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: Vpn.copied === extra.modelData.ip ? Icons.check : Icons.copy
                font.pixelSize: 13
                color: Vpn.copied === extra.modelData.ip ? Tokens.accent : Tokens.muted
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Vpn.copy(extra.modelData.ip)
            }
        }
    }

    // Pivots (ligolo-ng and other tun/WireGuard interfaces into internal networks): name and
    // agent, then the networks routed through it. Lime while up; muted when the agent is gone.
    Repeater {
        model: Vpn.pivots

        ColumnLayout {
            id: pivot
            required property var modelData

            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: pivot.modelData.up ? Tokens.accent : Tokens.muted
                }

                Label { text: "Pivot" }

                Txt {
                    text: pivot.modelData.name
                    font.family: Tokens.fontMono
                    font.pixelSize: 12
                    color: Tokens.ink
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: !pivot.modelData.up ? (pivot.modelData.agents.length === 0 && pivot.modelData.name.indexOf("lig") >= 0 ? "no agent" : "down")
                        : pivot.modelData.agents.length ? "agent " + pivot.modelData.agents.join(", ") : ""
                }
            }

            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                text: pivot.modelData.routes.length ? pivot.modelData.routes.join("  ") : "no route yet (ip route add <net> dev " + pivot.modelData.name + ")"
                wrapMode: Text.Wrap
                font.family: Tokens.fontMono
                font.pixelSize: 12
                color: pivot.modelData.routes.length && pivot.modelData.up ? Tokens.accent : Tokens.muted
            }
        }
    }
}
}
