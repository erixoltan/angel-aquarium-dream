import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Settings page: General. Each `cfg_<name>` property is two-way bound by
// Plasma to the matching entry in contents/config/main.xml.
Kirigami.FormLayout {
    property alias cfg_coolTemp: coolSpin.value
    property alias cfg_hotTemp: hotSpin.value
    property alias cfg_limitTemp: limitSpin.value
    property alias cfg_refreshSeconds: refreshSpin.value
    property alias cfg_showBackground: backgroundCheck.checked
    property alias cfg_showCaption: captionCheck.checked
    property alias cfg_caption: captionField.text

    QQC2.Label {
        text: i18n("The angelfish's sweater stripes fill as programs take memory (the disk cache doesn't count) and the collar shows swap in use. It moves as memory use changes, and turns red when the memory sticks get hot.")
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
        from: hotSpin.value + 1; to: 120
        textFromValue: function (v) { return i18n("%1 °C", v); }
        valueFromText: function (t) { return parseInt(t); }
    }
    QQC2.Label {
        text: i18n("The hottest memory stick counts. The halo starts to build above “Red at” if the heat lasts, and fades again when it cools. Programs waiting for memory also bring a halo, and wings when the whole system has to wait. Memory sticks without temperature sensors leave the angelfish a neutral colour.")
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
        placeholderText: "Memory"
    }

    QQC2.CheckBox {
        id: backgroundCheck
        Kirigami.FormData.label: i18n("Background:")
        text: i18n("Show widget background")
    }
}
