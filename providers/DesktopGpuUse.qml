import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

// How much of the GPU goes on drawing the desktop, so the aquarium can disclose its own cost
// (the GPU fish would otherwise show it as ordinary load). NVIDIA only: `nvidia-smi pmon` gives
// each process's share of the GPU's time, sampled over about a second.
//
//   shell       plasmashell (or plasmawindowed while testing): the wallpaper, panel and widgets
//   compositing KWin and the X server copying the screen; every redrawn wallpaper frame is
//               copied, but so are other windows' updates, so this is an upper bound
//   desktop     shell + compositing: what the desktop costs. With nothing else animating it is
//               essentially the wallpaper.
//   total       the whole GPU's utilisation, for comparison
//   stale       true while the GPU is saturated by something else: pmon then credits all the time
//               to the busy process and reports the desktop's processes as "-" (no sample), which
//               is not 0 (measured 2026-10-17 under a matmul load). The last real figures are kept.
// Values are percent; -1 = not known (no nvidia-smi, or no reading yet).
Item {
    id: use
    visible: false

    property bool active: true
    property int interval: 10000        // ms; each reading runs nvidia-smi twice (~1 s, low CPU)
    property real shell: -1
    property real compositing: -1
    property real total: -1
    property bool stale: false
    readonly property real desktop: shell < 0 ? -1 : shell + Math.max(0, compositing)
    readonly property bool known: shell >= 0

    readonly property var shellNames: ["plasmashell", "plasmawindowed"]
    readonly property var compositorNames: ["kwin_x11", "kwin_wayland", "Xorg", "Xwayland"]

    PlasmaCore.DataSource {
        id: smi
        engine: "executable"
        readonly property string command: "sh -c 'nvidia-smi pmon -c 1 -s u; "
            + "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits'"
        onNewData: {
            disconnectSource(sourceName);
            if (Number(data["exit code"]) !== 0) return;
            var shell = 0, comp = 0, total = -1, seen = false, sampled = false;
            var lines = String(data.stdout || "").split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (!line || line[0] === "#") continue;
                var f = line.split(/\s+/);
                if (f.length === 1 && isFinite(Number(f[0]))) { total = Number(f[0]); continue; }
                // gpu pid type sm mem enc dec ... command; "-" = idle in this sample
                if (f.length < 5) continue;
                var name = f[f.length - 1], sm = Number(f[3]);
                var mine = use.shellNames.indexOf(name) >= 0, compositor = use.compositorNames.indexOf(name) >= 0;
                if (!mine && !compositor) continue;
                if (isFinite(sm)) sampled = true; else sm = 0;
                if (mine) { shell += sm; seen = true; } else comp += sm;
            }
            use.total = total;
            // no sample for any desktop process while the GPU is busy: can't tell, keep the last
            if (!sampled && total >= 80 && use.known) { use.stale = true; return; }
            use.stale = false;
            use.shell = seen ? shell : 0;
            use.compositing = comp;
        }
    }
    Timer {
        interval: Math.max(5000, use.interval)
        running: use.active
        repeat: true
        triggeredOnStart: true
        onTriggered: smi.connectSource(smi.command)
    }
}
