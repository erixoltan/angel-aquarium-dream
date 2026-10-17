import QtQuick 2.15

// The Memory slot.
Swimmer {
    id: swimmer
    property var cfg
    property int interval: 4000
    kind: "memory"
    caption: cfg.memoryName || "Memory"
    depth: 0.5

    MemoryReadings { id: mem; interval: swimmer.interval }
    fish.fill: mem.fill
    fish.secondaryFill: mem.swap
    fish.activity: mem.activity
    fish.heat: mem.heat
    fish.distress: mem.distress
}
