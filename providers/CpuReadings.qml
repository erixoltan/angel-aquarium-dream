import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors

// CPU readings from Plasma's system stats service, turned into the 0..1 values a character takes.
// This is the only part of the CPU character that touches Plasma. The sensors module exists in
// Plasma 5 and 6 under the same name, so this file should serve both (checked on Plasma 5 only).
//
//   coreLoads  per thread (cpu/cpuN/usage)
//   heat       hottest core, from coolTemp (0) to hotTemp (1)
//   speed      average clock, relative to the lowest and highest seen since the widget started
//   distress   builds while the hottest core is past hotTemp, full at limitTemp; it takes time
//              to build and longer to fade, so a short spike barely shows
Item {
    id: cpu
    visible: false

    property int interval: 1000         // ms between readings
    property real coolTemp: 35          // °C
    property real hotTemp: 85
    property real limitTemp: 100
    property real riseSeconds: 20       // sustained heat at the limit to reach full distress
    property real fallSeconds: 40

    // raw readings, for anyone who wants numbers
    readonly property real usage: num(total.value)              // %
    readonly property real temperature: num(hottest.value)      // °C
    readonly property real frequency: num(clock.value)          // MHz
    readonly property int threads: Math.round(num(count.value))

    property var coreLoads: []
    readonly property real heat: clamp((temperature - coolTemp) / Math.max(1, hotTemp - coolTemp))
    property real speed: 0.5
    property real distress: 0

    function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    Sensors.Sensor { id: count; sensorId: "cpu/all/coreCount" }
    Sensors.Sensor { id: total; sensorId: "cpu/all/usage"; updateRateLimit: cpu.interval }
    Sensors.Sensor { id: hottest; sensorId: "cpu/all/maximumTemperature"; updateRateLimit: cpu.interval }
    Sensors.Sensor { id: clock; sensorId: "cpu/all/averageFrequency"; updateRateLimit: cpu.interval }
    // All per-thread loads in one model: 32 separate Sensor objects cost about ten times as much.
    Sensors.SensorDataModel {
        id: perCore
        updateRateLimit: cpu.interval
        sensors: {
            var ids = [];
            for (var i = 0; i < cpu.threads; i++) ids.push("cpu/cpu" + i + "/usage");
            return ids;
        }
    }

    property real lowestClock: 0
    property real highestClock: 0
    property double lastRead: 0
    Timer {
        interval: cpu.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var loads = [];
            for (var i = 0; i < perCore.columnCount(); i++) {
                var v = perCore.data(perCore.index(0, i), Sensors.SensorDataModel.Value);
                loads.push(cpu.clamp(cpu.num(v) / 100));
            }
            cpu.coreLoads = loads;

            var f = cpu.frequency;
            if (f > 0) {
                if (cpu.lowestClock === 0 || f < cpu.lowestClock) cpu.lowestClock = f;
                if (f > cpu.highestClock) cpu.highestClock = f;
                var range = cpu.highestClock - cpu.lowestClock;
                cpu.speed = range > 200 ? cpu.clamp((f - cpu.lowestClock) / range) : 0.5;
            }

            var now = Date.now(), dt = cpu.lastRead > 0 ? (now - cpu.lastRead) / 1000 : 0;
            cpu.lastRead = now;
            var target = cpu.clamp((cpu.temperature - cpu.hotTemp) / Math.max(1, cpu.limitTemp - cpu.hotTemp));
            if (target > cpu.distress)
                cpu.distress = Math.min(target, cpu.distress + dt / cpu.riseSeconds);
            else
                cpu.distress = Math.max(target, cpu.distress - dt / cpu.fallSeconds);
        }
    }
}
