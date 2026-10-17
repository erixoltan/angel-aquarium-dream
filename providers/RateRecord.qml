import QtQuick 2.15

// One direction of a flow (network download, disk write…) measured against its fastest rate
// ever, `max` (B/s). A rate counts once it has lasted `sustain` readings, so one odd sample doesn't
// set the record. The host stores the record (`known`) so it survives restarts; until it is
// learned it is at least `floorMax`. Call `update()` once per reading.
//
//   level   log scale: `quiet` B/s and below is 0, the record is 1
//   usage   linear share of the record: near 1 = as fast as it has ever gone
QtObject {
    id: record

    property real rate: 0               // B/s, the current reading
    property real quiet: 5000           // B/s that counts as nothing (background chatter)
    property real floorMax: 1e6         // B/s; the record starts here
    property int sustain: 3             // readings a rate must last to set a record
    property real known: 0              // record stored by the host, B/s

    property real max: Math.max(floorMax, known)
    readonly property real level: {
        if (rate <= quiet) return 0;
        return clamp(Math.log(rate / quiet) / Math.log(Math.max(max, quiet * 2) / quiet));
    }
    readonly property real usage: clamp(rate / max)

    property var recent: []
    function update() {
        recent.push(rate);
        while (recent.length > sustain) recent.shift();
        if (recent.length >= sustain) max = Math.max(max, Math.min.apply(null, recent));
    }
    function forget() { max = floorMax; recent = []; }

    function clamp(v) { return Math.max(0, Math.min(1, v)); }
}
