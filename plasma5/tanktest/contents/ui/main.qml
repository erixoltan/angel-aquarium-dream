import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

// Development only: the aquarium wallpaper's scene in a plasmawindowed window, so it can be
// checked without changing the desktop's wallpaper. A real CPU fish plus the five mood characters
// (Mood.qml). `pace` plays their moods faster: at 4 every spell shows within a minute or two.
Item {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    CpuReadings { id: cpu; interval: 2000 }

    property real pace: 1

    Plasmoid.fullRepresentation: Item {
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
