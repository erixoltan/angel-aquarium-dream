import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

// The drives Plasma's system stats service reports. It reports mounted volumes, with ids like
// "disk/ee69899f-…" (the filesystem's UUID) and names like "3.6 TiB Internal Drive (nvme0n1p2)",
// which end in the kernel's device name. Ids can't be guessed, so the list comes from
// `kstatsviewer --list` (part of ksystemstats), read once through the executable data engine.
QtObject {
    id: list

    property var ids: []                // "ee69899f-…"
    property var names: []              // "3.6 TiB Internal Drive (nvme0n1p2)"
    property var devices: []            // "nvme0n1p2"
    property bool loaded: false

    function nameOf(id) { var i = ids.indexOf(id); return i >= 0 ? names[i] : ""; }
    function deviceOf(id) { var i = ids.indexOf(id); return i >= 0 ? devices[i] : ""; }

    property PlasmaCore.DataSource source: PlasmaCore.DataSource {
        engine: "executable"
        readonly property string command: "kstatsviewer --list"
        Component.onCompleted: connectSource(command)
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            var ids = [], names = [], devices = [];
            var lines = String(data.stdout || "").split("\n");
            for (var i = 0; i < lines.length; i++) {
                var m = /^disk\/([^\/\s]+) (.*)$/.exec(lines[i].trim());
                if (!m || m[1] === "all") continue;
                var dev = /\(([A-Za-z0-9_-]+)\)$/.exec(m[2]);
                ids.push(m[1]);
                names.push(m[2]);
                devices.push(dev ? dev[1] : "");
            }
            list.ids = ids;
            list.names = names;
            list.devices = devices;
            list.loaded = true;
        }
    }
}
