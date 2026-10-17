import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Palettes.js" as Palettes

// The angelfish driven by sliders, with no real sensors, to design how it reads.
// Pure QtQuick; `make preview` shows it in a window.
Rectangle {
    id: preview
    color: "#0f2a3a"
    implicitWidth: 1180
    implicitHeight: 760

    // Each component's sweater stripes and matching dark outlines (common/Palettes.js); the
    // outlines can be switched to black for comparison.
    function inkFor(kind) { return inkMode.currentIndex === 1 ? "black" : Palettes.of(kind).ink; }
    readonly property string kind: Palettes.kinds.concat(Palettes.moods)[paletteBox.currentIndex]

    property var loads: []
    property int tick: 0
    function clamp(v) { return Math.max(0, Math.min(1, v)); }
    // A made-up machine: `busy` threads working at `level`, the rest nearly idle. With "hop" on,
    // the busy work lands on different cores every second, as a scheduler does.
    function simulate() {
        var n = Math.round(cores.value), b = Math.round(busy.value * n), out = [], order = [];
        for (var i = 0; i < n; i++) order.push(i);
        if (hop.checked) order.sort(function() { return Math.random() - 0.5; });
        for (i = 0; i < n; i++) out.push(0);
        for (i = 0; i < n; i++)
            out[order[i]] = clamp((i < b ? level.value : 0.04) + (Math.random() - 0.5) * 0.12);
        loads = out;
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: preview.simulate() }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Angelfish {
                Layout.fillWidth: true
                Layout.fillHeight: true
                kind: preview.kind
                stripes: gaugeMode.currentIndex === 1 ? [] : preview.loads
                fill: average(preview.loads)
                secondaryFill: gaugeMode.currentIndex === 1 ? collar.value : -1
                heat: heat.value
                speed: speed.value
                distress: distress.value
                sortStripes: sorted.checked
                intake: flowCheck.checked ? intake.value : -1
                outflow: flowCheck.checked ? outflow.value : -1
                split: flowCheck.checked ? intake.value / Math.max(0.01, intake.value + outflow.value) : -1
                asleep: asleepCheck.checked
                inkColor: preview.inkFor(kind)
            }
            // the same character in four situations, at widget size
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                Layout.fillHeight: false
                spacing: 8
                Repeater {
                    // either the same fish in four situations, or one fish per component
                    model: rowMode.currentIndex === 0 ? [
                        { name: "idle, cool", loads: [0.03, 0.05, 0.02, 0.04, 0.03, 0.02, 0.05, 0.03], heat: 0.1, speed: 0.15, distress: 0 },
                        { name: "one busy thread", loads: [0.05, 0.03, 0.98, 0.04, 0.06, 0.03, 0.02, 0.05], heat: 0.45, speed: 0.9, distress: 0 },
                        { name: "all busy, hot", loads: [0.95, 0.9, 1, 0.97, 0.92, 0.99, 0.94, 0.96], heat: 0.85, speed: 1, distress: 0.35 },
                        { name: "cooking", loads: [1, 1, 1, 1, 1, 1, 1, 1], heat: 1, speed: 0.4, distress: 1 }
                    ] : [
                        { name: "CPU", kind: "cpu", loads: [0.9, 0.7, 0.4, 0.3, 0.1, 0.05, 0.05, 0.02], heat: 0.5, speed: 0.8, distress: 0 },
                        { name: "GPU", kind: "gpu", fill: 0.85, collar: 0.4, heat: 0.7, speed: 0.9, distress: 0 },
                        { name: "Memory", kind: "memory", fill: 0.6, collar: 0.1, heat: 0.3, speed: 0.5, distress: 0 },
                        { name: "Disk", kind: "disk", fill: 0.35, heat: 0.35, speed: 0.5, distress: 0 },
                        { name: "Network", kind: "network", fill: 0.6, collar: 0.3, intake: 0.6, outflow: 0.3, split: 0.7, heat: -1, speed: 0.5, distress: 0 }
                    ]
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Angelfish {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            kind: modelData.kind === undefined ? preview.kind : modelData.kind
                            stripes: modelData.loads === undefined ? [] : modelData.loads
                            fill: modelData.fill === undefined ? average(stripes) : modelData.fill
                            secondaryFill: modelData.collar === undefined ? -1 : modelData.collar
                            heat: modelData.heat
                            speed: modelData.speed
                            distress: modelData.distress
                            intake: modelData.intake === undefined ? -1 : modelData.intake
                            outflow: modelData.outflow === undefined ? -1 : modelData.outflow
                            split: modelData.split === undefined ? -1 : modelData.split
                            inkColor: preview.inkFor(kind)
                        }
                        Label { text: modelData.name; color: "#cfe3ea"; Layout.alignment: Qt.AlignHCenter }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 280
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            spacing: 2
            component Knob: ColumnLayout {
                signal moved()
                property alias label: caption.text
                property alias value: slider.value
                property alias from: slider.from
                property alias to: slider.to
                property alias stepSize: slider.stepSize
                spacing: 0
                Label { id: caption; color: "#cfe3ea" }
                Slider { id: slider; Layout.fillWidth: true; onMoved: parent.moved() }
            }
            Knob { id: cores; onMoved: preview.simulate(); label: "Threads: " + Math.round(value); from: 1; to: 32; stepSize: 1; value: 16 }
            Knob { id: busy; onMoved: preview.simulate(); label: "Busy threads: " + Math.round(value * Math.round(cores.value)); value: 0.25 }
            Knob { id: level; onMoved: preview.simulate(); label: "Load on busy threads: " + Math.round(value * 100) + "%"; value: 0.9 }
            Knob { id: heat; label: "Temperature: " + Math.round(value * 100) + "% of limit"; value: 0.4 }
            Knob { id: speed; label: "Frequency: " + Math.round(value * 100) + "%"; value: 0.7 }
            Knob { id: collar; label: "Collar (VRAM, swap…): " + Math.round(value * 100) + "%"; value: 0.3; enabled: gaugeMode.currentIndex === 1 }
            Knob { id: distress; label: "Distress (halo): " + Math.round(value * 100) + "%"; value: 0 }
            CheckBox { id: flowCheck; text: "Eats and blows bubbles (network…)"; checked: false
                       contentItem: Label { text: flowCheck.text; color: "#cfe3ea"; leftPadding: flowCheck.indicator.width + 6; verticalAlignment: Text.AlignVCenter } }
            Knob { id: intake; label: "Flow in (food): " + Math.round(value * 100) + "%"; value: 0.5; enabled: flowCheck.checked }
            Knob { id: outflow; label: "Flow out (bubbles): " + Math.round(value * 100) + "%"; value: 0.2; enabled: flowCheck.checked }
            CheckBox { id: asleepCheck; text: "Asleep (offline)"; checked: false
                       contentItem: Label { text: asleepCheck.text; color: "#cfe3ea"; leftPadding: asleepCheck.indicator.width + 6; verticalAlignment: Text.AlignVCenter } }
            CheckBox { id: sorted; text: "Sort stripes by load"; checked: true
                       contentItem: Label { text: sorted.text; color: "#cfe3ea"; leftPadding: sorted.indicator.width + 6; verticalAlignment: Text.AlignVCenter } }
            CheckBox { id: hop; text: "Work hops between cores"; checked: true
                       contentItem: Label { text: hop.text; color: "#cfe3ea"; leftPadding: hop.indicator.width + 6; verticalAlignment: Text.AlignVCenter } }
            Label { text: "Sweater"; color: "#cfe3ea"; Layout.topMargin: 8 }
            ComboBox { id: paletteBox; Layout.fillWidth: true; model: Palettes.kinds.concat(Palettes.moods).map(function (k) { return Palettes.of(k).name; }) }
            Label { text: "Stripes"; color: "#cfe3ea" }
            ComboBox { id: gaugeMode; Layout.fillWidth: true; model: ["One per thread (CPU)", "Gauge of the average (GPU…)"] }
            Label { text: "Outlines"; color: "#cfe3ea" }
            ComboBox { id: inkMode; Layout.fillWidth: true; model: ["Dark shade of the sweater", "Black"] }
            Label { text: "Bottom row"; color: "#cfe3ea" }
            ComboBox { id: rowMode; Layout.fillWidth: true; model: ["Situations", "One fish per component"] }
        }
    }
}
