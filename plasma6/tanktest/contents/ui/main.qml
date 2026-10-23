import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

// Development only: the aquarium wallpaper's scene in a plasmawindowed window, so it can be
// checked without changing the desktop's wallpaper. A real CPU fish plus the five mood characters
// (Mood.qml). `pace` plays their moods faster: at 4 every spell shows within a minute or two.
// Plasma 6 version of plasma5/tanktest: an applet's root is a PlasmoidItem.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    CpuReadings { id: cpu; interval: 2000 }

    property real pace: 1

    fullRepresentation: Item {
        Layout.preferredWidth: 1280
        Layout.preferredHeight: 720
        Layout.minimumWidth: 640
        Layout.minimumHeight: 360

        Tank {
            anchors.fill: parent
            Swimmer {
                kind: "cpu"
                caption: "CPU (real)"
                fish.stripes: cpu.coreLoads
                fish.heat: cpu.heat
                fish.speed: cpu.speed
                fish.distress: cpu.distress
            }
            Repeater {
                model: ["dreamy", "anxious", "sleepy", "bling", "angry"]
                MoodFish { character: modelData; pace: root.pace; depth: index * 0.15 }
            }
        }
    }
}
