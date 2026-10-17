import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors
import org.kde.plasma.core 2.0 as PlasmaCore

// Memory readings from Plasma's system stats service, turned into the 0..1 values a character
// takes. DIMM temperatures and memory pressure come straight from the kernel through Plasma 5's
// executable data engine (Plasma5Support in Plasma 6), one small shell command every few seconds.
//
//   fill       memory held by programs (memory/physical/applicationPercent): the page cache
//              is not counted, it is given back as soon as programs need it
//   swap       used share of swap; 0 without swap
//   heat       hottest DIMM (hwmon spd5118 for DDR5, jc42 for DDR4), from coolTemp (0) to
//              hotTemp (1); -1 when the DIMMs have no sensors
//   activity   how fast programs take or give back memory, on a log scale: `quiet` B/s and
//              below is 0, `busy` B/s is 1
//   distress   memory pressure (/proc/pressure/memory), the share of time programs wait for
//              memory: "some" waiting brings a halo (at most `someDistress`), "full" (every
//              program waiting, the desktop freezes) brings wings. Hot DIMMs past hotTemp count
//              too, full at limitTemp. Without pressure readings, nearly full memory brings a
//              halo instead. It takes time to build and longer to fade, so a short spike barely
//              shows.
Item {
    id: mem
    visible: false

    property int interval: 1000         // ms between readings
    property real coolTemp: 30          // °C
    property real hotTemp: 70
    property real limitTemp: 85
    property real quiet: 1 << 20        // B/s
    property real busy: 1 << 30
    property real someFull: 20          // % of time some programs wait: full halo
    property real someDistress: 0.6     // most distress "some" waiting can cause (wings start at 0.65)
    property real fullFull: 10          // % of time every program waits: full distress
    property real riseSeconds: 20
    property real fallSeconds: 40

    // raw readings, for anyone who wants numbers
    readonly property real total: num(totalSensor.value)               // bytes
    readonly property real application: num(appSensor.value)          // bytes
    readonly property real swapPercent: num(swapSensor.value)          // %
    property real temperature: 0                                       // °C, hottest DIMM
    property bool hasTemperature: false
    property real someWaiting: 0                                       // % of the last 10 s
    property real fullWaiting: 0
    property bool hasPressure: false

    readonly property real fill: clamp(num(appPercentSensor.value) / 100)
    readonly property real swap: clamp(swapPercent / 100)
    readonly property real heat: hasTemperature ? clamp((temperature - coolTemp) / Math.max(1, hotTemp - coolTemp)) : -1
    property real activity: 0
    property real distress: 0

    function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    Sensors.Sensor { id: totalSensor; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: appSensor; sensorId: "memory/physical/application"; updateRateLimit: mem.interval }
    Sensors.Sensor { id: appPercentSensor; sensorId: "memory/physical/applicationPercent"; updateRateLimit: mem.interval }
    Sensors.Sensor { id: swapSensor; sensorId: "memory/swap/usedPercent"; updateRateLimit: mem.interval }

    // Prints "dimm <millidegrees>" per DIMM sensor, then the pressure file's two lines.
    PlasmaCore.DataSource {
        id: kernel
        engine: "executable"
        readonly property string command: "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in "
            + "spd5118|jc42) echo dimm $(cat $h/temp1_input);; esac; done 2>/dev/null; "
            + "cat /proc/pressure/memory 2>/dev/null"
        onNewData: {
            disconnectSource(sourceName);
            var lines = String(data.stdout || "").split("\n"), hottest = -1, some = -1, full = -1;
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].trim().split(/\s+/);
                if (f[0] === "dimm" && isFinite(Number(f[1])) && f[1] !== "")
                    hottest = Math.max(hottest, Number(f[1]) / 1000);
                var avg = /avg10=([\d.]+)/.exec(lines[i]);
                if (avg && f[0] === "some") some = Number(avg[1]);
                if (avg && f[0] === "full") full = Number(avg[1]);
            }
            mem.hasTemperature = hottest > 0;
            if (hottest > 0) mem.temperature = hottest;
            mem.hasPressure = some >= 0;
            mem.someWaiting = Math.max(0, some);
            mem.fullWaiting = Math.max(0, full);
        }
    }
    Timer {
        // temperatures and the 10 s pressure averages change slowly
        interval: Math.max(2000, mem.interval)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: kernel.connectSource(kernel.command)
    }

    property real lastApplication: -1
    property double lastRead: 0
    Timer {
        interval: mem.interval
        running: true
        repeat: true
        onTriggered: {
            var now = Date.now(), dt = mem.lastRead > 0 ? (now - mem.lastRead) / 1000 : 0;
            mem.lastRead = now;

            var a = mem.application;
            if (dt > 0 && mem.lastApplication >= 0 && a > 0) {
                var rate = Math.abs(a - mem.lastApplication) / dt;
                mem.activity = rate <= mem.quiet ? 0 : mem.clamp(Math.log(rate / mem.quiet) / Math.log(mem.busy / mem.quiet));
            }
            if (a > 0) mem.lastApplication = a;

            var hot = mem.hasTemperature
                ? mem.clamp((mem.temperature - mem.hotTemp) / Math.max(1, mem.limitTemp - mem.hotTemp)) : 0;
            var pressure = mem.hasPressure
                ? Math.max(mem.someDistress * mem.clamp(mem.someWaiting / mem.someFull), mem.clamp(mem.fullWaiting / mem.fullFull))
                : mem.someDistress * mem.clamp((mem.fill - 0.9) / 0.08);
            var target = Math.max(hot, pressure);
            if (target > mem.distress)
                mem.distress = Math.min(target, mem.distress + dt / mem.riseSeconds);
            else
                mem.distress = Math.max(target, mem.distress - dt / mem.fallSeconds);
        }
    }
}
