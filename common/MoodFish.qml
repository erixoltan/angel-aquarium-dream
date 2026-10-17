import QtQuick 2.15
import "Palettes.js" as Palettes

// A dream character in the tank: a Swimmer whose inputs come from its Mood instead of sensors.
// `character` is also its kind, which picks its sweater (Palettes.js) and its default name.
Swimmer {
    id: swimmer
    property string character: "dreamy"
    property alias pace: mood.pace
    property alias running: mood.running
    kind: character
    caption: Palettes.of(character).name

    Mood { id: mood; character: swimmer.character }
    fish.fill: mood.fill
    fish.activity: mood.activity
    fish.heat: mood.heat
    fish.speed: mood.speed
    fish.distress: mood.distress
    fish.asleep: mood.asleep
    fish.intake: mood.intake
    fish.outflow: mood.outflow
}
