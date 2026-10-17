import QtQuick 2.15

// The CPU slot: a Swimmer with its own readings. Loaded only while the slot is switched on.
Swimmer {
    id: swimmer
    property var cfg
    property int interval: 4000
    kind: "cpu"
    caption: cfg.cpuName || "CPU"
    depth: 0.1

    CpuReadings { id: cpu; interval: swimmer.interval }
    fish.stripes: cpu.coreLoads
    fish.heat: cpu.heat
    fish.speed: cpu.speed
    fish.distress: cpu.distress
}
