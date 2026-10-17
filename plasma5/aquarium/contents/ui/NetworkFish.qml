import QtQuick 2.15

// A Network slot (network1 or network2): one connection (<slot>Device, e.g. "wlo1") or all of them.
// Asleep while its connection is down. Lifetime records are kept in the settings like the disk
// fish's, and forgotten when another connection is picked. Unnamed, it's called after its
// connection's kind: Ethernet or Wi-Fi ("Network" for all traffic).
Swimmer {
    id: swimmer
    property var cfg
    property string slot: "network1"
    property int interval: 4000
    kind: "network"
    readonly property string device: cfg[slot + "Device"]
    caption: cfg[slot + "Name"] || (device ? links.labelOf(device) : "Network")
    NetworkList { id: links }
    depth: slot === "network1" ? 0.3 : 0.7

    NetworkReadings {
        id: net
        interval: swimmer.interval
        device: swimmer.device
        knownDown: swimmer.cfg[swimmer.slot + "MaxDown"]
        knownUp: swimmer.cfg[swimmer.slot + "MaxUp"]
    }
    property string lastDevice: device
    onDeviceChanged: {
        if (device === lastDevice) return;
        lastDevice = device;
        cfg[slot + "MaxDown"] = 0;
        cfg[slot + "MaxUp"] = 0;
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            var c = swimmer.cfg, s = swimmer.slot;
            if (net.maxDown > net.floorMax && net.maxDown > c[s + "MaxDown"]) c[s + "MaxDown"] = net.maxDown;
            if (net.maxUp > net.floorMax && net.maxUp > c[s + "MaxUp"]) c[s + "MaxUp"] = net.maxUp;
        }
    }

    fish.fill: net.connected ? net.level : 0
    fish.split: net.downShare
    fish.secondaryFill: net.connected ? net.usage : 0
    fish.activity: net.connected ? net.level : 0
    fish.intake: net.intake
    fish.outflow: net.outflow
    fish.asleep: !net.connected
    fish.heat: -1
    fish.speed: 0.5
    fish.distress: net.distress
}
