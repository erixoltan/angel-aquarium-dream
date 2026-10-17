import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

// Plasma 5 desktop widget: the angelfish character fed by network traffic. The character
// (Angelfish.qml) and the readings (NetworkReadings.qml) are shared; this file only reads the
// settings and connects the two.
Item {
    id: root
    // Read once and kept: `plasmoid` turns null while the widget is being removed, and a live
    // binding would then fail. The settings object itself stays the same for the widget's life.
    property var cfg: plasmoid.configuration
    Component.onCompleted: cfg = cfg

    Plasmoid.backgroundHints: cfg.showBackground
        ? PlasmaCore.Types.DefaultBackground
        : PlasmaCore.Types.NoBackground
    // Desktop widget only: always show the full representation.
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    Plasmoid.toolTipSubText: net.connected
        ? i18n("↓ %1   ↑ %2", bits(net.downloadRate), bits(net.uploadRate))
        : i18n("Not connected")
    function bits(bytesPerSecond) {
        var b = bytesPerSecond * 8;
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " Gbit/s" : b >= 1e6 ? (b / 1e6).toFixed(1) + " Mbit/s"
             : Math.round(b / 1e3) + " kbit/s";
    }

    NetworkReadings {
        id: net
        interval: Math.max(1, root.cfg.refreshSeconds) * 1000
        device: root.cfg.device
        knownDown: root.cfg.maxDown
        knownUp: root.cfg.maxUp
    }

    NetworkList { id: links }

    // The fastest rates ever seen are kept in the settings, so they survive restarts. Settings
    // set them to 0 to forget them.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (net.maxDown > net.floorMax && net.maxDown > root.cfg.maxDown) root.cfg.maxDown = net.maxDown;
            if (net.maxUp > net.floorMax && net.maxUp > root.cfg.maxUp) root.cfg.maxUp = net.maxUp;
        }
    }
    readonly property real storedDown: cfg.maxDown
    onStoredDownChanged: if (storedDown === 0) net.forget()

    // The fish with a name tag under it, so several fish on one desktop can be told apart.
    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.minimumWidth: PlasmaCore.Units.gridUnit * 5
        Layout.minimumHeight: PlasmaCore.Units.gridUnit * 5
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 16
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 16 * fish.implicitHeight / fish.implicitWidth
            + (tag.visible ? tag.implicitHeight + spacing : 0)
        spacing: 0

        // stripes fill with traffic, gold for the download part and teal for the upload; the
        // collar shows how close the line is to its fastest; no temperature, so a neutral body
        Angelfish {
            id: fish
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0     // whatever the tag leaves
            kind: "network"
            fill: net.connected ? net.level : 0
            split: net.downShare
            secondaryFill: net.connected ? net.usage : 0
            activity: net.connected ? net.level : 0
            intake: net.intake
            outflow: net.outflow
            asleep: !net.connected
            heat: -1
            speed: 0.5
            distress: net.distress
        }
        Caption {
            id: tag
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            visible: root.cfg.showCaption
            kind: "network"
            // unnamed, it's called after its connection's kind: Ethernet or Wi-Fi
            text: root.cfg.caption || (root.cfg.device ? links.labelOf(root.cfg.device) : "Network")
            // sized from the whole widget, not the fish, which shrinks as the tag grows
            pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize,
                Math.min(parent.width, parent.height * fish.implicitWidth / fish.implicitHeight) * 0.065)
        }
    }
}
