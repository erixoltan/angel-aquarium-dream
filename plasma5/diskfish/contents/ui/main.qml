import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

// Plasma 5 desktop widget: the angelfish character fed by one drive's readings, or all drives
// together. The character (Angelfish.qml) and the readings (DiskReadings.qml) are shared; this
// file only reads the settings and connects the two.
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

    Plasmoid.toolTipSubText: (disk.name ? disk.name + "\n" : "")
        + i18n("read %1   write %2", rate(disk.readRate), rate(disk.writeRate))
        + "\n" + i18n("%1% full", Math.round(disk.space * 100))
        + (disk.hasTemperature ? "   " + i18n("%1 °C", Math.round(disk.temperature)) : "")
    function rate(bytesPerSecond) {
        return bytesPerSecond >= 1e9 ? (bytesPerSecond / 1e9).toFixed(1) + " GB/s"
             : bytesPerSecond >= 1e6 ? (bytesPerSecond / 1e6).toFixed(1) + " MB/s"
             : Math.round(bytesPerSecond / 1e3) + " kB/s";
    }

    DiskReadings {
        id: disk
        interval: Math.max(1, root.cfg.refreshSeconds) * 1000
        device: root.cfg.device
        knownRead: root.cfg.maxRead
        knownWrite: root.cfg.maxWrite
    }

    // The fastest rates ever seen are kept in the settings, so they survive restarts. Settings
    // set them to 0 to forget them (also when another drive is picked).
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (disk.maxRead > disk.floorMax && disk.maxRead > root.cfg.maxRead) root.cfg.maxRead = disk.maxRead;
            if (disk.maxWrite > disk.floorMax && disk.maxWrite > root.cfg.maxWrite) root.cfg.maxWrite = disk.maxWrite;
        }
    }
    readonly property real storedRead: cfg.maxRead
    onStoredReadChanged: if (storedRead === 0) disk.forget()

    // The fish with a name tag under it, so several fish on one desktop can be told apart.
    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.minimumWidth: PlasmaCore.Units.gridUnit * 5
        Layout.minimumHeight: PlasmaCore.Units.gridUnit * 5
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 16
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 16 * fish.implicitHeight / fish.implicitWidth
            + (tag.visible ? tag.implicitHeight + spacing : 0)
        spacing: 0

        // stripes fill with traffic, gold for the writing part and orange for the reading; the
        // collar fills with the drive; no clock, so a middling body brightness
        Angelfish {
            id: fish
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0     // whatever the tag leaves
            kind: "disk"
            fill: disk.level
            split: disk.writeShare
            secondaryFill: disk.space
            activity: disk.level
            intake: disk.intake
            outflow: disk.outflow
            heat: disk.heat
            speed: 0.5
            distress: disk.distress
        }
        Caption {
            id: tag
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            visible: root.cfg.showCaption
            kind: "disk"
            text: root.cfg.caption || "Disk"
            // sized from the whole widget, not the fish, which shrinks as the tag grows
            pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize,
                Math.min(parent.width, parent.height * fish.implicitWidth / fish.implicitHeight) * 0.065)
        }
    }
}
