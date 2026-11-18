import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services

// RAVEN: listening sockets you started. One click copies LHOST:port (VPN up) or the port.
ColumnLayout {
    id: root

    property int maxRows: 5
    property bool showEmpty: false     // say "Nothing listening" instead of hiding (desktop card)

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        spacing: 8

        Rectangle {
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: Listeners.any ? Tokens.accent : Tokens.off
        }

        Label { text: "Listeners" }

        Item { Layout.fillWidth: true }

        Label {
            text: String(Listeners.list.length)
            color: Tokens.ink
        }
    }

    Repeater {
        model: Listeners.list.slice(0, root.maxRows)

        Item {
            id: row
            required property var modelData
            readonly property bool justCopied: Listeners.copied !== "" && Listeners.copied === Listeners.target(row.modelData)

            Layout.fillWidth: true
            implicitHeight: 24

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -6
                anchors.rightMargin: -6
                radius: 6
                color: hover.containsMouse ? Tokens.raised : "transparent"
            }

            Label {
                id: proto
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                text: row.modelData.proto
            }

            Txt {
                id: port
                anchors.left: proto.right
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                text: String(row.modelData.port)
                font.family: Tokens.fontMono
                font.pixelSize: 14
                color: hover.containsMouse || row.justCopied ? Tokens.accent : Tokens.ink
                elide: Text.ElideNone
            }

            Txt {
                anchors.left: port.right
                anchors.right: where.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.justCopied ? "Copied " + Listeners.copied : (row.modelData.proc || "root")
                color: row.justCopied ? Tokens.accent : Tokens.dim
                font.pixelSize: 12
            }

            Label {
                id: where
                anchors.right: mark.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.addr === "all" ? "all" : row.modelData.addr.startsWith("127.") || row.modelData.addr === "::1" ? "lo" : row.modelData.addr
            }

            Ico {
                id: mark
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: row.justCopied ? Icons.check : Icons.copy
                font.pixelSize: 13
                color: row.justCopied ? Tokens.accent : hover.containsMouse ? Tokens.ink : Tokens.muted
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Listeners.copy(row.modelData)
            }
        }
    }

    Label {
        visible: root.showEmpty && !Listeners.any
        text: "Nothing listening"
        color: Tokens.muted
    }

    Label {
        visible: Listeners.list.length > root.maxRows
        text: "+ " + (Listeners.list.length - root.maxRows) + " more"
    }
}
