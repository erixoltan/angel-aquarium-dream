import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

// Plasma 5 desktop widget: the angelfish character fed by memory readings. The character
// (Angelfish.qml) and the readings (MemoryReadings.qml) are shared; this file only reads the
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
    Plasmoid.toolTipSubText: i18n("%1 of %2 in use", gib(mem.application), gib(mem.total))
    function gib(bytes) { return (bytes / 1073741824).toFixed(1) + " GiB"; }

    MemoryReadings {
        id: mem
        interval: Math.max(1, root.cfg.refreshSeconds) * 1000
        coolTemp: root.cfg.coolTemp
        hotTemp: root.cfg.hotTemp
        limitTemp: root.cfg.limitTemp
    }

    // The fish with a name tag under it, so several fish on one desktop can be told apart.
    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.minimumWidth: PlasmaCore.Units.gridUnit * 5
        Layout.minimumHeight: PlasmaCore.Units.gridUnit * 5
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 14
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 14 * fish.implicitHeight / fish.implicitWidth
            + (tag.visible ? tag.implicitHeight + spacing : 0)
        spacing: 0

        // stripes fill as programs take memory, the collar as swap fills; no clock, so a
        // middling body brightness like the network fish
        Angelfish {
            id: fish
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0     // whatever the tag leaves
            kind: "memory"
            fill: mem.fill
            secondaryFill: mem.swap
            activity: mem.activity
            heat: mem.heat
            speed: 0.5
            distress: mem.distress
        }
        Caption {
            id: tag
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            visible: root.cfg.showCaption
            kind: "memory"
            text: root.cfg.caption || "Memory"
            // sized from the whole widget, not the fish, which shrinks as the tag grows
            pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize,
                Math.min(parent.width, parent.height * fish.implicitWidth / fish.implicitHeight) * 0.065)
        }
    }
}
