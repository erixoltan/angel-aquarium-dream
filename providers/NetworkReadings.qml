import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors
import org.kde.plasma.core 2.0 as PlasmaCore

// Network traffic from Plasma's system stats service, all connections together or one (`device`,
// e.g. "wlo1"), turned into the 0..1 values a character takes. The connection check uses Plasma 5's executable data engine
// (Plasma5Support in Plasma 6).
//
// Each direction is measured against its fastest rate ever (`maxDown`, `maxUp`, B/s; see
// RateRecord.qml). The host stores them so they survive restarts.
//
//   level      busier direction on a log scale: `quiet` B/s and below is 0, the record is 1
//   downShare  how much of the traffic is download, 0..1 (by bytes)
//   intake     level × downShare (food), outflow = level × upShare (bubbles): a download sends
//              acknowledgements back, but they are a few percent of the bytes, so few bubbles
//   usage      linear share of the record in the busier direction: near 1 = the line is full
//   connected  a default route, and the internet answers pings (3 misses in a row = broken);
//              for one connection, the route must go through it and the pings are sent out
//              through it. A connection that's down has no sensors at all (ksystemstats lists
//              only connections that are up), so its rates read 0 and it simply isn't connected.
//   distress   builds while the line stays nearly full (halo only, at most `fullDistress`) or
//              the connection is lost (wings); it takes time to build and longer to fade. For one
//              connection, "lost" means it was up earlier: a Wi-Fi that's simply switched off
//              sleeps peacefully. All traffic with no connection at all is always trouble.
Item {
    id: net
    visible: false

    property string device: ""          // a connection ("enp4s0", "wlo1"); empty = all of them
    property int interval: 1000         // ms between readings
    property real quiet: 5000           // B/s that counts as nothing (background chatter)
    property real floorMax: 1e6         // B/s; records start here
    property int sustain: 3             // readings a rate must last to set a record
    property real knownDown: 0          // records stored by the host, B/s
    property real knownUp: 0
    property var probeHosts: ["1.1.1.1", "8.8.8.8"]
    property int probeSeconds: 15
    property real fullFrom: 0.8         // usage where the halo starts
    property real fullDistress: 0.6     // most distress a full line can cause (wings start at 0.65)
    property real riseSeconds: 20
    property real fallSeconds: 40

    // raw readings, B/s
    readonly property real downloadRate: num(downSensor.value)
    readonly property real uploadRate: num(upSensor.value)

    readonly property real maxDown: down.max
    readonly property real maxUp: up.max
    readonly property real level: Math.max(down.level, up.level)
    readonly property real downShare: downloadRate + uploadRate > 0 ? downloadRate / (downloadRate + uploadRate) : 0.5
    readonly property real intake: connected ? level * downShare : 0
    readonly property real outflow: connected ? level * (1 - downShare) : 0
    readonly property real usage: Math.max(down.usage, up.usage)
    readonly property bool connected: routed && misses < 3
    // Logged only when it changes, so `journalctl --user -t plasmashell | grep "network fish"`
    // says when and why a fish fell asleep (a sleep seen once on 2026-10-17 couldn't be
    // reproduced afterwards).
    property bool checked: false        // a check has come back (no log while starting up)
    property bool everConnected: false  // up at some point since starting (or since `device` changed)
    readonly property bool lost: !connected && (device === "" || everConnected)
    onConnectedChanged: if (checked) console.log("network fish: " + (connected ? "connected again"
        : routed ? "no answer from " + probeHosts.join(" or ") + " three times running" : "no default route")
        + (device ? " (" + device + ")" : ""))
    property bool routed: true
    property int misses: 0
    property real distress: 0

    // forget the records (the host's "reset" in settings)
    function forget() { down.forget(); up.forget(); }

    function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    readonly property string sensorPrefix: "network/" + (device || "all") + "/"
    Sensors.Sensor { id: downSensor; sensorId: net.sensorPrefix + "download"; updateRateLimit: net.interval }
    Sensors.Sensor { id: upSensor; sensorId: net.sensorPrefix + "upload"; updateRateLimit: net.interval }
    // another connection: its records and its history of missed pings don't carry over
    onDeviceChanged: { forget(); misses = 0; routed = true; checked = false; everConnected = false; }
    RateRecord { id: down; rate: net.downloadRate; quiet: net.quiet; floorMax: net.floorMax; sustain: net.sustain; known: net.knownDown }
    RateRecord { id: up; rate: net.uploadRate; quiet: net.quiet; floorMax: net.floorMax; sustain: net.sustain; known: net.knownUp }

    property double lastRead: 0
    Timer {
        interval: net.interval
        running: true
        repeat: true
        onTriggered: {
            down.update();
            up.update();

            var now = Date.now(), dt = net.lastRead > 0 ? (now - net.lastRead) / 1000 : 0;
            net.lastRead = now;
            var full = net.fullDistress * net.clamp((net.usage - net.fullFrom) / Math.max(0.01, 0.95 - net.fullFrom));
            var target = net.connected ? full : net.lost ? 1 : 0;
            if (target > net.distress)
                net.distress = Math.min(target, net.distress + dt / net.riseSeconds);
            else
                net.distress = Math.max(target, net.distress - dt / net.fallSeconds);
        }
    }

    // A default route, then a ping to the first host that answers. Prints the routes, then the
    // ping's exit status after "ping=".
    PlasmaCore.DataSource {
        id: check
        engine: "executable"
        readonly property string command: {
            // only interface names reach the shell (from /sys/class/net, or the settings)
            var dev = /^[A-Za-z0-9_.:-]+$/.test(net.device) ? net.device : "";
            var via = dev ? " dev " + dev : "", out = dev ? " -I " + dev : "";
            var pings = net.probeHosts.map(function (h) { return "ping -c1 -n -W3" + out + " " + h + " >/dev/null 2>&1"; });
            return "ip route show default" + via + " 2>/dev/null; ip -6 route show default" + via
                + " 2>/dev/null; " + pings.join(" || ") + "; echo ping=$?";
        }
        onNewData: {
            disconnectSource(sourceName);
            var out = String(data.stdout || ""), at = out.lastIndexOf("ping=");
            if (at < 0) return;
            net.routed = out.slice(0, at).trim() !== "";
            var answered = net.routed && out.slice(at + 5).trim() === "0";
            net.misses = answered ? 0 : net.misses + 1;
            net.checked = true;
            if (net.connected) net.everConnected = true;
        }
    }
    Timer {
        // quicker while a miss is being confirmed
        interval: (net.misses > 0 && net.misses < 3 ? 5 : net.probeSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: check.connectSource(check.command)
    }
}
