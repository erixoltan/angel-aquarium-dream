import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.5 as Kirigami

// The wallpaper's settings page, shown under Configure Desktop and Wallpaper. One page only:
// Plasma 5 wallpapers can't have tabs.
Kirigami.FormLayout {
    id: page
    twinFormLayouts: parentLayout
    property alias formLayout: page

    property alias cfg_refreshSeconds: interval.value
    property alias cfg_fps: fps.value
    property alias cfg_waterSpeed: waterSpeed.value

    property alias cfg_cpuOn: cpuRow.on
    property alias cfg_cpuName: cpuRow.name
    property alias cfg_memoryOn: memoryRow.on
    property alias cfg_memoryName: memoryRow.name
    property alias cfg_gpu1On: gpu1Row.on
    property alias cfg_gpu1Name: gpu1Row.name
    property alias cfg_gpu1Device: gpu1Row.device
    property alias cfg_gpu2On: gpu2Row.on
    property alias cfg_gpu2Name: gpu2Row.name
    property alias cfg_gpu2Device: gpu2Row.device
    property alias cfg_disk1On: disk1Row.on
    property alias cfg_disk1Name: disk1Row.name
    property alias cfg_disk1Device: disk1Row.device
    property alias cfg_disk2On: disk2Row.on
    property alias cfg_disk2Name: disk2Row.name
    property alias cfg_disk2Device: disk2Row.device
    property alias cfg_network1On: network1Row.on
    property alias cfg_network1Name: network1Row.name
    property alias cfg_network1Device: network1Row.device
    property alias cfg_network2On: network2Row.on
    property alias cfg_network2Name: network2Row.name
    property alias cfg_network2Device: network2Row.device
    property alias cfg_showDesktopGpu: showDesktopGpu.checked
    property alias cfg_dreamyOn: dreamyRow.on
    property alias cfg_dreamyName: dreamyRow.name
    property alias cfg_anxiousOn: anxiousRow.on
    property alias cfg_anxiousName: anxiousRow.name
    property alias cfg_sleepyOn: sleepyRow.on
    property alias cfg_sleepyName: sleepyRow.name
    property alias cfg_blingOn: blingRow.on
    property alias cfg_blingName: blingRow.name
    property alias cfg_angryOn: angryRow.on
    property alias cfg_angryName: angryRow.name

    GpuList { id: gpus }
    DiskList { id: disks }
    NetworkList { id: links }
    DesktopGpuUse { id: gpuUse; interval: 5000 }

    readonly property var gpuChoices: {
        var out = [{ text: "First one found", value: "" }];
        for (var i = 0; i < gpus.ids.length; i++)
            out.push({ text: gpus.names[i] + " (" + gpus.ids[i] + ")", value: gpus.ids[i] });
        return out;
    }
    readonly property var diskChoices: {
        var out = [{ text: "All drives", value: "" }];
        for (var i = 0; i < disks.ids.length; i++)
            out.push({ text: disks.names[i], value: disks.ids[i] });
        return out;
    }

    readonly property var networkChoices: {
        var out = [{ text: "All traffic", value: "" }];
        for (var i = 0; i < links.ids.length; i++)
            out.push({ text: links.labelOf(links.ids[i]) + " (" + links.ids[i] + ")", value: links.ids[i] });
        return out;
    }

    // ---- fish ----
    QQC2.Label {
        Kirigami.FormData.label: "Angelfish:"
        text: "Tick an angelfish to show it, pick its device, and name it (empty = the usual name)."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
    SlotRow { id: cpuRow; Kirigami.FormData.label: "CPU:"; defaultName: "CPU" }
    SlotRow { id: memoryRow; Kirigami.FormData.label: "Memory:"; defaultName: "Memory" }
    SlotRow { id: gpu1Row; Kirigami.FormData.label: "GPU 1:"; defaultName: "GPU"; choices: page.gpuChoices }
    SlotRow { id: gpu2Row; Kirigami.FormData.label: "GPU 2:"; defaultName: "GPU"; choices: page.gpuChoices }
    SlotRow { id: disk1Row; Kirigami.FormData.label: "Disk 1:"; defaultName: "Disk"; choices: page.diskChoices }
    SlotRow { id: disk2Row; Kirigami.FormData.label: "Disk 2:"; defaultName: "Disk"; choices: page.diskChoices }
    SlotRow {
        id: network1Row
        Kirigami.FormData.label: "Network 1:"
        defaultName: device ? links.labelOf(device) : "Network"
        choices: page.networkChoices
    }
    SlotRow {
        id: network2Row
        Kirigami.FormData.label: "Network 2:"
        defaultName: device ? links.labelOf(device) : "Network"
        choices: page.networkChoices
    }
    QQC2.Label {
        text: "A network angelfish sleeps on the sand while its connection is down.\n"
            + "Temperatures use each part's own limits, so there's nothing to set."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- dream characters ----
    QQC2.Label {
        Kirigami.FormData.label: "Dream angelfish:"
        text: "Angelfish that stand for nothing on the computer, each with a temperament\n"
            + "of its own that comes and goes. Each costs about 1% of a CPU core, for its swimming."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
    SlotRow { id: dreamyRow; Kirigami.FormData.label: "Dreamy:"; defaultName: "Dreamy" }
    SlotRow { id: anxiousRow; Kirigami.FormData.label: "Anxious:"; defaultName: "Anxious" }
    SlotRow { id: sleepyRow; Kirigami.FormData.label: "Sleepy:"; defaultName: "Sleepy" }
    SlotRow { id: blingRow; Kirigami.FormData.label: "Bling:"; defaultName: "Bling" }
    SlotRow { id: angryRow; Kirigami.FormData.label: "Angry:"; defaultName: "Angry" }

    Item { Kirigami.FormData.isSection: true }

    // ---- cost ----
    QQC2.SpinBox {
        id: interval
        Kirigami.FormData.label: "Sensor interval:"
        from: 1
        to: 60
        textFromValue: function (v) { return v + " s"; }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.Label {
        text: "Readings are about half the cost: with five angelfish, 2 s takes ~15% of a CPU core\n"
            + "and 4 s ~9%. The angelfish keep swimming smoothly either way."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
    QQC2.SpinBox {
        id: fps
        Kirigami.FormData.label: "Frame rate:"
        from: 5
        to: 60
        textFromValue: function (v) { return v + " fps"; }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.Label {
        text: "Smoother costs more: each frame redraws the whole screen. 20 looks smooth;\n"
            + "10 and below look choppy. The tank stops while a maximised window covers it."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
    RowLayout {
        Kirigami.FormData.label: "Water speed:"
        QQC2.Slider {
            id: waterSpeed
            from: 0
            to: 200
            stepSize: 5
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        }
        QQC2.Label { text: waterSpeed.value + "%" }
    }
    QQC2.Label {
        Kirigami.FormData.label: "GPU right now:"
        visible: gpuUse.known
        text: "Drawing the desktop takes " + Math.round(gpuUse.desktop) + "% of the GPU: plasmashell "
            + Math.round(gpuUse.shell) + "% (this wallpaper, the panel, widgets),\nKWin and X "
            + Math.round(gpuUse.compositing) + "% (copying the screen, other windows too). Whole GPU: "
            + Math.round(gpuUse.total) + "%."
            + (gpuUse.stale ? "\nThe GPU is busy with other work, which hides the desktop's share; these are the last figures seen." : "")
        font: Kirigami.Theme.smallFont
    }
    QQC2.CheckBox {
        id: showDesktopGpu
        text: "Show the desktop's GPU use under the GPU angelfish"
    }
    QQC2.Label {
        text: "The GPU angelfish's stripes include the wallpaper's own load; this says how much."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
