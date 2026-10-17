import QtQuick 2.15
import QtQml.Models 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors

// The GPUs Plasma's system stats service reports, as ids like "gpu2" with their names. The ids
// follow the kernel's DRM card numbers, so they don't start at gpu0 (here an Intel iGPU without
// sensors is card1 and the RTX 3090 is gpu2). A GPU counts when it has a name sensor.
QtObject {
    id: list

    property int probe: 8               // gpu0 .. gpu7
    property var ids: []
    property var names: []

    function nameOf(id) {
        var i = ids.indexOf(id);
        return i >= 0 ? names[i] : "";
    }

    function rescan() {
        var ids = [], names = [];
        for (var i = 0; i < sensors.count; i++) {
            var s = sensors.objectAt(i), v = s ? s.value : undefined;
            if (v !== undefined && v !== null && String(v) !== "") {
                ids.push("gpu" + i);
                names.push(String(v));
            }
        }
        if (JSON.stringify(ids) !== JSON.stringify(list.ids) || JSON.stringify(names) !== JSON.stringify(list.names)) {
            list.ids = ids;
            list.names = names;
        }
    }

    property Instantiator sensors: Instantiator {
        model: list.probe
        delegate: Sensors.Sensor {
            sensorId: "gpu/gpu" + index + "/name"
            onValueChanged: list.rescan()
        }
        onObjectAdded: list.rescan()
    }
}
