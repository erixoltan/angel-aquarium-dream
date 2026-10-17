import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Settings page: General. Each `cfg_<name>` property is two-way bound by
// Plasma to the matching entry in contents/config/main.xml.
Kirigami.FormLayout {
    property string cfg_device
    property alias cfg_coolTemp: coolSpin.value
    property alias cfg_hotTemp: hotSpin.value
    property alias cfg_limitTemp: limitSpin.value
    property alias cfg_refreshSeconds: refreshSpin.value
    property alias cfg_showBackground: backgroundCheck.checked
    property alias cfg_showCaption: captionCheck.checked
    property alias cfg_caption: captionField.text

    GpuList { id: gpus }

    QQC2.Label {
        text: i18n("The angelfish's sweater stripes fill from the collar as the graphics card gets busy, and the collar shows how full its video memory is. It turns red as it gets hot and grows a halo, then wings, when it stays too hot or slows itself down to cope.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: deviceBox
        Kirigami.FormData.label: i18n("Graphics card:")
        readonly property var choices: {
            var out = [{ text: i18n("First one found"), value: "" }];
            for (var i = 0; i < gpus.ids.length; i++)
                out.push({ text: gpus.names[i] + " (" + gpus.ids[i] + ")", value: gpus.ids[i] });
            return out;
        }
        model: choices
        textRole: "text"
        valueRole: "value"
        currentIndex: Math.max(0, indexOfValue(cfg_device))
        onActivated: cfg_device = currentValue
    }
    QQC2.Label {
        text: i18n("For more than one graphics card, add an angelfish for each.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: coolSpin
        Kirigami.FormData.label: i18n("Blue at:")
        from: 0; to: hotSpin.value - 1
        textFromValue: function (v) { return i18n("%1 °C", v); }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.SpinBox {
        id: hotSpin
        Kirigami.FormData.label: i18n("Red at:")
        from: coolSpin.value + 1; to: limitSpin.value - 1
        textFromValue: function (v) { return i18n("%1 °C", v); }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.SpinBox {
        id: limitSpin
        Kirigami.FormData.label: i18n("Full halo at:")
        from: hotSpin.value + 1; to: 130
        textFromValue: function (v) { return i18n("%1 °C", v); }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.Label {
        text: i18n("The halo starts to build above “Red at” if the heat lasts, and fades again when it cools. Nearly full video memory also brings a halo, but no wings. A card that slows itself down because of heat or power gets a halo or wings too, and says why in its tooltip. For an NVIDIA card, “nvidia-smi -q -d TEMPERATURE” shows its target and maximum operating temperatures.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: i18n("Read sensors every:")
        from: 1; to: 60
        textFromValue: function (v) { return i18np("%1 second", "%1 seconds", v); }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.Label {
        text: i18n("Reading the sensors costs a little CPU; a longer interval costs less. The angelfish keeps swimming smoothly either way.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: captionCheck
        Kirigami.FormData.label: i18n("Name tag:")
        text: i18n("Show a name tag under the angelfish")
    }
    QQC2.TextField {
        id: captionField
        enabled: captionCheck.checked
        placeholderText: "GPU"
    }

    QQC2.CheckBox {
        id: backgroundCheck
        Kirigami.FormData.label: i18n("Background:")
        text: i18n("Show widget background")
    }
}
