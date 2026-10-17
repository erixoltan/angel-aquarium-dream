import QtQuick 2.15

// A GPU slot (gpu1 or gpu2). A small line under its tag says how much of the GPU drawing the
// desktop takes, the wallpaper included, so the fish's own load isn't mistaken for work
// (DesktopGpuUse.qml). Setting showDesktopGpu, on by default.
Swimmer {
    id: swimmer
    property var cfg
    property string slot: "gpu1"
    property int interval: 4000
    property var desktopUse              // a DesktopGpuUse, shared by the host
    kind: "gpu"
    depth: slot === "gpu1" ? 0.25 : 0.65
    visible: gpu.present
    caption: cfg[slot + "Name"] || "GPU"
    // why the card is slowing itself down (always shown: it's trouble), then the desktop's share
    readonly property string desktopNote: cfg.showDesktopGpu && desktopUse && desktopUse.known && gpu.nvidia
        ? "desktop uses " + (desktopUse.stale ? "~" : "") + Math.round(desktopUse.desktop) + "% of GPU"
          + (desktopUse.stale ? " (last seen)" : "") : ""
    note: [gpu.throttle ? "slowing itself: " + gpu.throttle : "", desktopNote]
        .filter(function (t) { return t !== ""; }).join("\n")

    GpuReadings { id: gpu; interval: swimmer.interval; device: swimmer.cfg[swimmer.slot + "Device"] }
    fish.fill: gpu.fill
    fish.secondaryFill: gpu.vram
    fish.heat: gpu.heat
    fish.speed: gpu.speed
    fish.distress: gpu.distress
}
