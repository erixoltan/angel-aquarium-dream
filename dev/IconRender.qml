import QtQuick 2.15

// Renders each widget's icon for "Add Widgets": the fish at full throttle, with halo and wings,
// on a transparent background. `make icons` runs this in plasmawindowed; the output folder is
// filled in when the package is assembled. Each fish is saved once it has settled; plasmawindowed
// ignores Qt.quit(), so make stops it with a timeout.
Item {
    id: render
    readonly property string outDir: "@ICONS@"
    readonly property int size: 256
    // widget id -> fish kind
    // The network and disk fish's halos mean a full line, a lost connection or a full drive, so
    // their icons show them eating and blowing bubbles instead.
    readonly property var widgets: [{ name: "cpufish", kind: "cpu" }, { name: "gpufish", kind: "gpu" },
                                    { name: "netfish", kind: "network", flow: true },
                                    { name: "memfish", kind: "memory" },
                                    { name: "diskfish", kind: "disk", flow: true }]
    implicitWidth: size * widgets.length
    implicitHeight: size

    Row {
        Repeater {
            model: render.widgets
            Angelfish {
                id: fish
                width: render.size
                height: render.size
                kind: modelData.kind
                stripes: modelData.kind === "cpu" ? [1, 1, 1, 1, 1, 1, 1, 1] : []
                fill: 1
                secondaryFill: 1
                heat: modelData.flow ? -1 : 1
                speed: 1
                distress: modelData.flow ? 0 : 1
                intake: modelData.flow ? 1 : -1
                outflow: modelData.flow ? 0.6 : -1
                split: modelData.flow ? 0.65 : -1
                foodColor: modelData.food || "#dca024"
                // food and bubbles only move while animating
                animate: !!modelData.flow
                // the eyelid and colours ease in; save after they have caught up
                Timer {
                    interval: 2500
                    running: true
                    onTriggered: fish.grabToImage(function (result) {
                        result.saveToFile(render.outDir + "/" + modelData.name + ".png");
                        console.log("saved", render.outDir + "/" + modelData.name + ".png");
                    }, Qt.size(render.size, render.size))
                }
            }
        }
    }
}
