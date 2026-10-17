// Which component a fish is: the sweater's stripe colour plus a darker ink of the same hue for
// the outlines. Learn one fish and the colours tell the others apart.
.pragma library

var palettes = {
    cpu:     { name: "CPU",     stripe: "#27306b", ink: "#141a3d" },
    gpu:     { name: "GPU",     stripe: "#3f8a24", ink: "#183d0c" },
    memory:  { name: "Memory",  stripe: "#6a2c91", ink: "#2f1045" },
    disk:    { name: "Disk",    stripe: "#c2601c", ink: "#552606" },
    network: { name: "Network", stripe: "#1f7f86", ink: "#0b3a3e" }
};
var kinds = ["cpu", "gpu", "memory", "disk", "network"];

function of(kind) { return palettes[kind] || palettes.cpu; }
