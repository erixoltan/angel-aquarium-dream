import QtQuick 2.15

// The inner life of a character that stands for nothing on the computer: a dream figure with a
// temperament, acted out in the angelfish's own grammar. Pure QtQuick; it plays the part of a
// provider, so a host connects its outputs to an Angelfish like readings.
//
// A character lives in spells: a calm one, then its own kind of episode, each of a random length,
// and its inputs follow a smooth curve through the spell (rise, hold, fade), so nothing jumps.
//   dreamy   drifts slowly, half asleep, trailing a few bubbles; dozes off now and then
//   anxious  mostly fine, but a worry builds every so often: fidgeting, it works itself up until
//            it overheats (red) and a halo appears; about one worry in three gets as far as wings
//   sleepy   asleep on the sand for long stretches, dreaming of being an angel: towards the end of
//            every sleep a halo, then wings, which fade as it wakes; awake briefly, sleeps again
//   bling    cruises, then shows off in bursts of flat-out swimming, rainbow sweater full
//   angry    simmers, then flares up: flushes red, swims hard, fumes bubbles; at the height of it
//            a halo, and about one flare in three wings, then it cools down again
// Halo and wings are what make them angelfish, so the characters show them often; the real fish
// keep them for harm.
Item {
    id: mood
    visible: false

    property string character: "dreamy"
    property bool running: true
    property real pace: 1               // > 1 plays the script faster (the test tank)

    // outputs, for an Angelfish (same meanings and ranges)
    property real fill: 0.2
    property real activity: 0.2
    property real heat: 0.35
    property real speed: 0.5
    property real distress: 0
    property bool asleep: false
    readonly property real intake: -1   // no character eats
    property real outflow: blows ? 0 : -1
    // characters that blow bubbles, fume or snore keep room in front of the mouth all the time
    // (an Angelfish snores z's only if it has that room)
    readonly property bool blows: character === "dreamy" || character === "angry" || character === "sleepy"

    // the spell: its name, how far through it is (seconds), how long it lasts, how strong it is
    property string spell: ""
    property real age: 0
    property real length: 1
    property real strength: 1

    function rnd(lo, hi) { return lo + Math.random() * (hi - lo); }
    function clamp(v) { return Math.max(0, Math.min(1, v)); }
    function smooth(t) { t = clamp(t); return t * t * (3 - 2 * t); }
    // 0 → 1 over the first `rise` of the spell, 1 until `fall`, back to 0 by the end
    function arc(rise, fall) {
        var t = age / length;
        return t < rise ? smooth(t / rise) : t < fall ? 1 : 1 - smooth((t - fall) / (1 - fall));
    }
    function begin(name, lo, hi) { spell = name; age = 0; length = rnd(lo, hi); }

    // what comes after the current spell (and the first one: a character starts calm, except
    // Sleepy, who starts asleep)
    function next() {
        switch (character) {
        case "dreamy":  if (spell === "drift") begin("doze", 12, 30); else begin("drift", 40, 100); break;
        case "anxious":
            if (spell === "worry") begin("calm", 50, 120);
            else { begin("worry", 45, 80); strength = Math.random() < 0.33 ? rnd(0.85, 1) : rnd(0.4, 0.6); }
            break;
        case "sleepy":  if (spell === "sleep") begin("awake", 15, 35); else begin("sleep", 60, 150); break;
        case "bling":   if (spell === "burst") begin("cruise", 15, 35); else begin("burst", 6, 12); break;
        case "angry":
            if (spell === "calm") { begin("fume", 30, 50); strength = Math.random() < 0.33 ? rnd(0.85, 1) : rnd(0.4, 0.6); }
            else begin("calm", 40, 100);
            break;
        }
    }

    // Colours are what cost: every change of fill, heat or speed repaints the fish. So they move
    // in steps of 1/24 (finer is hard to see) and only the tail and eye (activity) wobble freely.
    function step(v) { return Math.round(v * 24) / 24; }
    function setColours(f, h, s) {
        f = step(f); h = step(h); s = step(s);
        if (fill !== f) fill = f;
        if (heat !== h) heat = h;
        if (speed !== s) speed = s;
    }

    // set the outputs for this moment of the spell
    function apply() {
        var wobble = Math.sin(age * 0.25);          // slow drift within a spell
        switch (character) {
        case "dreamy":
            var dozing = spell === "doze";
            asleep = dozing;
            activity = dozing ? 0 : 0.18 + 0.06 * wobble;
            setColours(0.3, 0.4, 0.6);
            outflow = dozing ? 0 : 0.06;
            break;
        case "anxious":
            var w = spell === "worry" ? strength * arc(0.35, 0.6) : 0;
            distress = w;
            activity = clamp(0.35 + 0.45 * w + 0.12 * Math.random());     // fidgets
            // works itself up until it overheats: red at the height of a big worry
            setColours(0.3 + 0.6 * w, 0.35 + 0.65 * Math.min(1, w / 0.6), 0.6);
            break;
        case "sleepy":
            var awake = spell === "awake" ? arc(0.2, 0.8) : 0;
            asleep = spell === "sleep";
            // the angel dream: halo from 55% of the sleep, wings from about 80%, gone soon after
            // waking (distress fades over the first third of being awake)
            distress = asleep ? smooth((age / length - 0.55) / 0.4)
                     : Math.min(distress, 1 - smooth(age / length / 0.35));
            activity = 0.12 * awake;
            setColours(0.15, 0.3, 0.3 + 0.2 * awake);
            break;
        case "bling":
            var b = spell === "burst" ? arc(0.15, 0.8) : 0;
            activity = 0.3 + 0.7 * b + 0.05 * wobble;
            setColours(0.45 + 0.55 * b, 0.5, 1);
            break;
        case "angry":
            var a = spell === "fume" ? arc(0.25, 0.65) : 0;
            // the halo comes at the height of it, after the flush, and goes before it cools
            distress = spell === "fume" ? strength * arc(0.4, 0.7) : 0;
            activity = 0.25 + 0.65 * a;
            setColours(0.2 + 0.8 * a, 0.18 + 0.8 * a, 0.5 + 0.5 * a);
            outflow = a > 0.5 ? a : 0;
            break;
        }
    }

    function tick(dt) {
        age += dt;
        if (age >= length) next();
        apply();
    }

    // Every 2 s, like the real fish's readings: spells last tens of seconds, and the fish eases
    // its colours in between. Updating twice a second doubled the wallpaper's CPU use.
    Timer {
        interval: 2000
        running: mood.running
        repeat: true
        onTriggered: mood.tick(2 * mood.pace)
    }
    // a random point in its first spell, so several characters don't keep step
    Component.onCompleted: {
        if (character === "sleepy") spell = "awake";
        next();
        age = Math.random() * length * 0.8;
        apply();
    }
}
