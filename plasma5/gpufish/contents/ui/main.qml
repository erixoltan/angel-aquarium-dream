import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

// Plasma 5 desktop widget: the angelfish character fed by one GPU's readings. For several GPUs,
// add the widget once per GPU. The character (Angelfish.qml) and the readings (GpuReadings.qml)
// are shared; this file only reads the settings and connects the two.
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
    Plasmoid.toolTipSubText: gpu.name + (gpu.throttle ? "\n" + i18n("Slowing itself down: %1", gpu.throttle) : "")

    // Under a maximised or full-screen window the desktop keeps drawing unseen (measured
    // 2026-10-17: five widgets, 13% of a core and 17% of the GPU, all hidden), so the fish stops
    // moving and readings slow to one every 10 s, as in the aquarium.
    CoverWatch { id: cover }

    GpuReadings {
        id: gpu
        interval: (cover.covered ? 10 : Math.max(1, root.cfg.refreshSeconds)) * 1000
        device: root.cfg.device
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

        Angelfish {
            id: fish
            animate: !cover.covered
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0     // whatever the tag leaves
            kind: "gpu"
            fill: gpu.fill
            secondaryFill: gpu.vram
            heat: gpu.heat
            speed: gpu.speed
            distress: gpu.distress
        }
        Caption {
            id: tag
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            visible: root.cfg.showCaption
            kind: "gpu"
            text: root.cfg.caption || "GPU"
            // sized from the whole widget, not the fish, which shrinks as the tag grows
            pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize,
                Math.min(parent.width, parent.height * fish.implicitWidth / fish.implicitHeight) * 0.065)
        }
    }
}
