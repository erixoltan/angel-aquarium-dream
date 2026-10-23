import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

// The network connections a fish can watch, from /sys/class/net, whether or not they're up:
// Plasma's system stats service lists only the ones that are up, and a Wi-Fi fish has to exist
// (asleep) while its Wi-Fi is down. Loopback and virtual interfaces (Docker bridges, veth, …)
// are left out. Read once through the executable data engine.
QtObject {
    id: list
    property var ids: []                // "enp4s0", "wlo1"
    property var kinds: []              // "wired" | "wifi"
    property bool loaded: false

    function kindOf(id) { var i = ids.indexOf(id); return i >= 0 ? kinds[i] : guess(id); }
    // a name for a connection, by its kind (also guessed from the name before the list loads)
    function labelOf(id) { return kindOf(id) === "wifi" ? "Wi-Fi" : "Ethernet"; }
    function guess(id) { return /^(wl|wlan|ath|ra)/.test(id) ? "wifi" : "wired"; }

    readonly property var skip: /^(lo|docker|br-|veth|virbr|vnet|tap|dummy)/

    property PlasmaCore.DataSource source: PlasmaCore.DataSource {
        engine: "executable"
        readonly property string command: "sh -c 'for d in /sys/class/net/*; do n=${d##*/}; "
            + "t=wired; [ -d \"$d/wireless\" ] && t=wifi; echo \"$n $t\"; done'"
        Component.onCompleted: connectSource(command)
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            var ids = [], kinds = [];
            var lines = String(data.stdout || "").split("\n");
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].trim().split(/\s+/);
                if (f.length < 2 || list.skip.test(f[0])) continue;
                ids.push(f[0]);
                kinds.push(f[1]);
            }
            list.ids = ids;
            list.kinds = kinds;
            list.loaded = true;
        }
    }
}
