import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors
import org.kde.plasma.core 2.0 as PlasmaCore

// One GPU's readings from Plasma's system stats service, turned into the 0..1 values a character
// takes. The sensors module exists in Plasma 5 and 6 under the same name; the nvidia-smi
// correction below uses Plasma 5's executable data engine (Plasma5Support in Plasma 6).
//
//   fill       utilisation (gpu/gpuN/usage)
//   vram       used share of video memory
//   heat       GPU temperature, from coolTemp (0) to hotTemp (1)
//   speed      core clock, relative to the lowest and highest seen since the widget started
//   distress   builds while the GPU is past hotTemp, full at limitTemp. Nearly full video memory
//              adds a halo but never wings: it slows things down, it doesn't hurt the card.
//              It takes time to build and longer to fade, so a short spike barely shows.
//              NVIDIA cards also report when they slow themselves down: for heat (software
//              thermal slowdown) that builds a halo (`throttleDistress`); a hardware slowdown or
//              power brake is an emergency and builds wings. Running at the power limit is not
//              counted: a 3090 does that at any full load (measured 2026-10-17), it's hard work.
//   throttle   why the card is slowing itself down, in words; "" = it isn't (NVIDIA only)
Item {
    id: gpu
    visible: false

    property string device: ""          // "gpu2"; empty or missing = the first GPU found
    property int interval: 1000         // ms between readings
    property real coolTemp: 35          // °C
    property real hotTemp: 83
    property real limitTemp: 93
    property real riseSeconds: 20       // sustained heat at the limit to reach full distress
    property real fallSeconds: 40
    property real vramFullFrom: 0.9     // video memory share where the halo starts
    property real vramDistress: 0.6     // most distress full video memory can cause (wings start at 0.65)
    property real throttleDistress: 0.6 // distress while slowing itself for heat (a halo, no wings)

    GpuList { id: gpus }
    readonly property string active: gpus.ids.indexOf(device) >= 0 ? device : (gpus.ids.length ? gpus.ids[0] : "")
    readonly property string name: gpus.nameOf(active) || ""
    readonly property bool present: active !== ""

    // raw readings, for anyone who wants numbers
    readonly property real usage: num(usageSensor.value)                // %
    readonly property real temperature: num(tempSensor.value)           // °C
    readonly property real frequency: num(clockSensor.value)            // MHz
    readonly property real usedVram: smiTotal > 0 ? smiUsed : num(usedSensor.value)     // MiB
    readonly property real totalVram: smiTotal > 0 ? smiTotal : num(totalSensor.value)  // MiB

    readonly property real fill: clamp(usage / 100)
    readonly property real vram: totalVram > 0 ? clamp(usedVram / totalVram) : 0
    readonly property real heat: present ? clamp((temperature - coolTemp) / Math.max(1, hotTemp - coolTemp)) : -1
    property real speed: 0.5
    property real distress: 0

    function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    readonly property string prefix: "gpu/" + active + "/"
    Sensors.Sensor { id: usageSensor; sensorId: gpu.present ? gpu.prefix + "usage" : ""; updateRateLimit: gpu.interval }
    Sensors.Sensor { id: tempSensor; sensorId: gpu.present ? gpu.prefix + "temperature" : ""; updateRateLimit: gpu.interval }
    Sensors.Sensor { id: clockSensor; sensorId: gpu.present ? gpu.prefix + "coreFrequency" : ""; updateRateLimit: gpu.interval }
    Sensors.Sensor { id: usedSensor; sensorId: gpu.present ? gpu.prefix + "usedVram" : ""; updateRateLimit: gpu.interval }
    Sensors.Sensor { id: totalSensor; sensorId: gpu.present ? gpu.prefix + "totalVram" : "" }

    // On NVIDIA cards Plasma 5.27 adds the PCIe BAR to the video memory (here 24 GiB of memory
    // plus a 32 GiB resizable BAR reads as 56 GiB), so a full card would look less than half
    // full. nvidia-smi reports the real numbers; it takes ~25 ms, so it runs every 5 s at most. GPUs are
    // matched by name, in order, when several share one.
    property real smiUsed: 0
    property real smiTotal: 0
    property string throttle: ""
    property bool emergency: false      // hardware slowdown or power brake
    readonly property bool nvidia: /nvidia/i.test(name)
    readonly property int sameNameIndex: {
        var k = 0;
        for (var i = 0; i < gpus.ids.length && gpus.ids[i] !== active; i++)
            if (gpus.names[i] === name) k++;
        return k;
    }
    PlasmaCore.DataSource {
        id: smi
        engine: "executable"
        // the throttle reasons use their older names, which newer drivers still accept
        readonly property string command: "nvidia-smi --query-gpu=name,memory.used,memory.total,"
            + "clocks_throttle_reasons.sw_thermal_slowdown,clocks_throttle_reasons.hw_thermal_slowdown,"
            + "clocks_throttle_reasons.hw_slowdown,clocks_throttle_reasons.hw_power_brake_slowdown"
            + " --format=csv,noheader,nounits"
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            var k = 0, lines = String(data.stdout || "").split("\n");
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].split(",").map(function (x) { return x.trim(); });
                if (f.length < 3 || f[0] !== gpu.name) continue;
                if (k++ !== gpu.sameNameIndex) continue;
                var used = Number(f[1]), total = Number(f[2]);
                if (isFinite(used) && isFinite(total) && total > 0) { gpu.smiUsed = used; gpu.smiTotal = total; }
                function on(k) { return f.length > k && f[k] === "Active"; }
                var why = [];
                if (on(3)) why.push("too hot");
                if (on(4)) why.push("too hot (hardware)");
                if (on(5)) why.push("hardware slowdown");
                if (on(6)) why.push("power brake");
                gpu.throttle = why.join(", ");
                gpu.emergency = on(4) || on(5) || on(6);
                return;
            }
        }
    }
    Timer {
        interval: Math.max(5000, gpu.interval)
        running: gpu.nvidia
        repeat: true
        triggeredOnStart: true
        onTriggered: smi.connectSource(smi.command)
    }

    property real lowestClock: 0
    property real highestClock: 0
    property double lastRead: 0
    onActiveChanged: { smiUsed = 0; smiTotal = 0; lowestClock = 0; highestClock = 0; throttle = ""; emergency = false; }
    Timer {
        interval: gpu.interval
        running: gpu.present
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var f = gpu.frequency;
            if (f > 0) {
                if (gpu.lowestClock === 0 || f < gpu.lowestClock) gpu.lowestClock = f;
                if (f > gpu.highestClock) gpu.highestClock = f;
                var range = gpu.highestClock - gpu.lowestClock;
                gpu.speed = range > 200 ? gpu.clamp((f - gpu.lowestClock) / range) : 0.5;
            }

            var now = Date.now(), dt = gpu.lastRead > 0 ? (now - gpu.lastRead) / 1000 : 0;
            gpu.lastRead = now;
            var hot = gpu.clamp((gpu.temperature - gpu.hotTemp) / Math.max(1, gpu.limitTemp - gpu.hotTemp));
            var full = gpu.vramDistress * gpu.clamp((gpu.vram - gpu.vramFullFrom) / Math.max(0.01, 0.98 - gpu.vramFullFrom));
            var slowed = gpu.emergency ? 1 : gpu.throttle !== "" ? gpu.throttleDistress : 0;
            var target = Math.max(hot, full, slowed);
            if (target > gpu.distress)
                gpu.distress = Math.min(target, gpu.distress + dt / gpu.riseSeconds);
            else
                gpu.distress = Math.max(target, gpu.distress - dt / gpu.fallSeconds);
        }
    }
}
