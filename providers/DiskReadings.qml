import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors
import org.kde.plasma.core 2.0 as PlasmaCore

// One drive's readings (or all drives together) from Plasma's system stats service, turned into
// the 0..1 values a character takes. Drive temperatures come straight from the kernel (hwmon: nvme
// for NVMe drives, drivetemp for SATA) through Plasma 5's executable data engine (Plasma5Support
// in Plasma 6), with the warning and critical temperatures the drive itself reports.
//
// Reads and writes are measured against their fastest rates ever (`maxRead`, `maxWrite`, B/s; see
// RateRecord.qml). The host stores them so they survive restarts.
//
//   level      busier direction on a log scale: `quiet` B/s and below is 0, the record is 1
//   writeShare how much of the traffic is writing, 0..1 (by bytes)
//   intake     level × writeShare (food: data going into the drive), outflow = level × readShare
//              (bubbles: data coming out)
//   space      used share of the space
//   heat       hottest drive, from coolTemp (0) to its warning temperature (1); -1 = no sensor
//   distress   builds while a drive is past its warning temperature, full at its critical one
//              (wings), or while the drive is nearly full (halo only, at most `fullDistress`).
//              It takes time to build and longer to fade, so a short spike barely shows.
Item {
    id: disk
    visible: false

    property string device: ""          // system stats id (a filesystem UUID); empty or missing = all drives
    property int interval: 1000         // ms between readings
    property real quiet: 100e3          // B/s that counts as nothing (logs, browser profiles)
    property real floorMax: 100e6       // B/s; records start here
    property int sustain: 3             // readings a rate must last to set a record
    property real knownRead: 0          // records stored by the host, B/s
    property real knownWrite: 0
    property real coolTemp: 30          // °C
    property real hotTemp: 70           // when a drive doesn't report its warning temperature
    property real fullFrom: 0.9         // used space where the halo starts
    property real fullDistress: 0.6     // most distress a full drive can cause (wings start at 0.65)
    property real riseSeconds: 20
    property real fallSeconds: 40

    DiskList { id: disks }
    readonly property string active: disks.ids.indexOf(device) >= 0 ? device : "all"
    readonly property string name: active === "all" ? "" : disks.nameOf(active)

    // raw readings, B/s
    readonly property real readRate: num(readSensor.value)
    readonly property real writeRate: num(writeSensor.value)
    property real temperature: 0        // °C, the drive closest to its warning temperature
    property bool hasTemperature: false

    readonly property real maxRead: reads.max
    readonly property real maxWrite: writes.max
    readonly property real level: Math.max(reads.level, writes.level)
    readonly property real writeShare: readRate + writeRate > 0 ? writeRate / (readRate + writeRate) : 0.5
    readonly property real intake: level * writeShare
    readonly property real outflow: level * (1 - writeShare)
    readonly property real space: clamp(num(usedSensor.value) / 100)
    property real heat: -1
    property real hot: 0                // 0..1 from warning to critical temperature
    property real distress: 0

    // forget the records (the host's "reset" in settings)
    function forget() { reads.forget(); writes.forget(); }

    function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    readonly property string prefix: "disk/" + active + "/"
    Sensors.Sensor { id: readSensor; sensorId: disk.prefix + "read"; updateRateLimit: disk.interval }
    Sensors.Sensor { id: writeSensor; sensorId: disk.prefix + "write"; updateRateLimit: disk.interval }
    Sensors.Sensor { id: usedSensor; sensorId: disk.prefix + "usedPercent"; updateRateLimit: disk.interval }
    RateRecord { id: reads; rate: disk.readRate; quiet: disk.quiet; floorMax: disk.floorMax; sustain: disk.sustain; known: disk.knownRead }
    RateRecord { id: writes; rate: disk.writeRate; quiet: disk.quiet; floorMax: disk.floorMax; sustain: disk.sustain; known: disk.knownWrite }

    // For each device (a partition is traced to its drive), prints "temp <input> <max> <crit>"
    // in millidegrees per sensor; a missing limit prints as 0.
    readonly property var devices: {
        var out = active === "all" ? disks.devices : [disks.deviceOf(active)];
        return out.filter(function (d) { return /^[A-Za-z0-9_-]+$/.test(d); });
    }
    PlasmaCore.DataSource {
        id: kernel
        engine: "executable"
        readonly property string command: "for n in " + disk.devices.join(" ") + "; do b=/sys/class/block/$n; "
            + "[ -f $b/partition ] && b=$(readlink -f $b/..); "
            + "for h in $b/device/hwmon* $b/device/hwmon/hwmon*; do [ -f $h/temp1_input ] && "
            + "echo temp $(cat $h/temp1_input) $(cat $h/temp1_max || echo 0) $(cat $h/temp1_crit || echo 0); "
            + "done; done 2>/dev/null"
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            var lines = String(data.stdout || "").split("\n"), found = false, heat = 0, hot = 0, shown = 0;
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].trim().split(/\s+/);
                if (f[0] !== "temp" || f.length < 4) continue;
                var t = Number(f[1]) / 1000, max = Number(f[2]) / 1000, crit = Number(f[3]) / 1000;
                if (!isFinite(t) || t <= 0) continue;
                // some drives report nonsense limits
                if (!(max >= 40 && max <= 120)) max = disk.hotTemp;
                if (!(crit > max && crit <= 130)) crit = max + 10;
                var h = disk.clamp((t - disk.coolTemp) / Math.max(1, max - disk.coolTemp));
                if (!found || h > heat) { heat = h; shown = t; }
                hot = Math.max(hot, disk.clamp((t - max) / (crit - max)));
                found = true;
            }
            disk.hasTemperature = found;
            disk.temperature = shown;
            disk.heat = found ? heat : -1;
            disk.hot = hot;
        }
    }
    Timer {
        interval: Math.max(5000, disk.interval)
        running: disk.devices.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: kernel.connectSource(kernel.command)
    }

    property double lastRead: 0
    Timer {
        interval: disk.interval
        running: true
        repeat: true
        onTriggered: {
            reads.update();
            writes.update();

            var now = Date.now(), dt = disk.lastRead > 0 ? (now - disk.lastRead) / 1000 : 0;
            disk.lastRead = now;
            var full = disk.fullDistress * disk.clamp((disk.space - disk.fullFrom) / Math.max(0.01, 0.98 - disk.fullFrom));
            var target = Math.max(disk.hot, full);
            if (target > disk.distress)
                disk.distress = Math.min(target, disk.distress + dt / disk.riseSeconds);
            else
                disk.distress = Math.max(target, disk.distress - dt / disk.fallSeconds);
        }
    }
}
