import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

// Development only: the aquarium wallpaper's scene in a plasmawindowed window, so it can be
// checked without changing the desktop's wallpaper. A real CPU fish plus four demo fish whose
// inputs follow a fast script, so every way of moving shows within a minute or two:
//   Busy     activity swings between idle and flat out (speed follows the tail beat)
//   Sleepy   asleep for 25 s of every 60: sinks to the sand, then rises again
//   Worried  distress climbs to 1 and falls over 80 s: rises, wings near the surface
//   Steady   middling, as a reference
Item {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    CpuReadings { id: cpu; interval: 2000 }

    property real t: 0
    Timer { interval: 500; running: true; repeat: true; onTriggered: root.t += 0.5 }
    function wave(period, phase) { return 0.5 - 0.5 * Math.cos(2 * Math.PI * (root.t / period + phase)); }

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
            Swimmer {
                kind: "gpu"
                caption: "Busy"
                depth: 0.2
                fish.fill: root.wave(30, 0)
                fish.heat: 0.2 + 0.6 * root.wave(30, 0)
            }
            Swimmer {
                kind: "network"
                caption: "Sleepy"
                depth: 0.35
                readonly property bool sleeping: (root.t % 60) < 25
                fish.asleep: sleeping
                fish.fill: sleeping ? 0 : 0.4
                fish.activity: sleeping ? 0 : 0.4
                fish.intake: sleeping ? 0 : 0.3
                fish.outflow: sleeping ? 0 : 0.1
                fish.heat: -1
            }
            Swimmer {
                kind: "memory"
                caption: "Worried"
                depth: 0.5
                fish.fill: 0.6
                fish.distress: root.wave(80, 0.25)
                fish.heat: 0.3 + 0.6 * root.wave(80, 0.25)
            }
            Swimmer {
                kind: "disk"
                caption: "Steady"
                depth: 0.65
                fish.fill: 0.35
                fish.intake: 0.2
                fish.outflow: 0.2
                fish.split: 0.5
            }
        }
    }
}
