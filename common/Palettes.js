// Which component a fish is: the sweater's stripe colour plus a darker ink of the same hue for
// the outlines. Learn one fish and the colours tell the others apart.
//
// The mood characters (Mood.qml) stand for nothing on the computer, so they wear colours no
// component uses, on a pale sweater of their own (`base`; the components' sweaters are cream):
// a tint opposite the stripe colour on the colour wheel, so the stripes stand out, and all of the
// same lightness, so the five read as one family. Bling's sweater has a band of every colour
// (`bands`, one per band from the collar, repeating) on neutral grey; its collar and tag are gold.
.pragma library

var palettes = {
    cpu:     { name: "CPU",     stripe: "#27306b", ink: "#141a3d" },
    gpu:     { name: "GPU",     stripe: "#3f8a24", ink: "#183d0c" },
    memory:  { name: "Memory",  stripe: "#6a2c91", ink: "#2f1045" },
    disk:    { name: "Disk",    stripe: "#c2601c", ink: "#552606" },
    network: { name: "Network", stripe: "#1f7f86", ink: "#0b3a3e" },

    dreamy:  { name: "Dreamy",  stripe: "#d982b0", ink: "#5c2145", base: "#cdeedb" },   // on mint
    anxious: { name: "Anxious", stripe: "#7b8794", ink: "#2a3038", base: "#f5d6e1" },   // on pink
    sleepy:  { name: "Sleepy",  stripe: "#8a5a3b", ink: "#3a2212", base: "#cfe0f5" },   // on blue
    bling:   { name: "Bling",   stripe: "#d6a419", ink: "#4d3500", base: "#e3e4e9",  // on grey
               bands: ["#e0413a", "#f08a24", "#f2cf2e", "#4fb83f", "#2f8fd8", "#6b4fc8", "#c64fb0"] },
    angry:   { name: "Angry",   stripe: "#b3243a", ink: "#4a0b16", base: "#f8eec2" }    // on yellow
};
var kinds = ["cpu", "gpu", "memory", "disk", "network"];
var moods = ["dreamy", "anxious", "sleepy", "bling", "angry"];

function of(kind) { return palettes[kind] || palettes.cpu; }
