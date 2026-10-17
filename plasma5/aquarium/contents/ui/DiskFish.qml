import QtQuick 2.15

// A Disk slot (disk1 or disk2): one drive or all of them. The fastest read and write rates ever
// seen are kept in the settings (<slot>MaxRead/MaxWrite), so they survive restarts; picking
// another drive forgets them.
Swimmer {
    id: swimmer
    property var cfg
    property string slot: "disk1"
    property int interval: 4000
    kind: "disk"
    caption: cfg[slot + "Name"] || "Disk"
    depth: slot === "disk1" ? 0.4 : 0.75

    readonly property string device: cfg[slot + "Device"]
    DiskReadings {
        id: disk
        interval: swimmer.interval
        device: swimmer.device
        knownRead: swimmer.cfg[swimmer.slot + "MaxRead"]
        knownWrite: swimmer.cfg[swimmer.slot + "MaxWrite"]
    }
    property string lastDevice: device
    onDeviceChanged: {
        if (device === lastDevice) return;
        lastDevice = device;
        cfg[slot + "MaxRead"] = 0;
        cfg[slot + "MaxWrite"] = 0;
        disk.forget();
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            var c = swimmer.cfg, s = swimmer.slot;
            if (disk.maxRead > disk.floorMax && disk.maxRead > c[s + "MaxRead"]) c[s + "MaxRead"] = disk.maxRead;
            if (disk.maxWrite > disk.floorMax && disk.maxWrite > c[s + "MaxWrite"]) c[s + "MaxWrite"] = disk.maxWrite;
        }
    }

    fish.fill: disk.level
    fish.split: disk.writeShare
    fish.secondaryFill: disk.space
    fish.activity: disk.level
    fish.intake: disk.intake
    fish.outflow: disk.outflow
    fish.heat: disk.heat
    fish.distress: disk.distress
}
