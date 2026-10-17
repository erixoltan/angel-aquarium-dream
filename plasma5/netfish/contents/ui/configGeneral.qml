import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Settings page: General. Each `cfg_<name>` property is two-way bound by
// Plasma to the matching entry in contents/config/main.xml.
Kirigami.FormLayout {
    property string cfg_device
    property alias cfg_refreshSeconds: refreshSpin.value
    property alias cfg_showBackground: backgroundCheck.checked
    property alias cfg_showCaption: captionCheck.checked
    property alias cfg_caption: captionField.text
    property real cfg_maxDown
    property real cfg_maxUp

    function bits(bytesPerSecond) {
        var b = bytesPerSecond * 8;
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " Gbit/s" : (b / 1e6).toFixed(1) + " Mbit/s";
    }

    QQC2.Label {
        text: i18n("The angelfish eats what you download and blows bubbles as you upload. Its sweater stripes fill with all traffic, gold for the download part and teal for the upload. The collar shows how close the line is to the fastest it has ever been; when it stays nearly full the halo appears. When the connection is down (no route, or the internet doesn't answer pings to 1.1.1.1 or 8.8.8.8) it falls asleep and goes dark, and if it was working earlier it soon grows wings. A connection that's simply switched off, like an unused Wi-Fi, just sleeps.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    NetworkList { id: links }

    QQC2.ComboBox {
        id: deviceBox
        Kirigami.FormData.label: i18n("Connection:")
        readonly property var choices: {
            var out = [{ text: i18n("All traffic"), value: "" }];
            for (var i = 0; i < links.ids.length; i++)
                out.push({ text: links.labelOf(links.ids[i]) + " (" + links.ids[i] + ")", value: links.ids[i] });
            return out;
        }
        model: choices
        textRole: "text"
        valueRole: "value"
        currentIndex: Math.max(0, indexOfValue(cfg_device))
        // the fastest rates belong to the connection they were seen on
        onActivated: if (currentValue !== cfg_device) { cfg_device = currentValue; cfg_maxDown = 0; cfg_maxUp = 0; }
    }
    QQC2.Label {
        text: i18n("For an angelfish per connection, add one for each.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.Label {
        Kirigami.FormData.label: i18n("Fastest so far:")
        text: cfg_maxDown > 0 || cfg_maxUp > 0
            ? i18n("↓ %1   ↑ %2", bits(cfg_maxDown), bits(cfg_maxUp))
            : i18n("not learned yet")
    }
    QQC2.Button {
        text: i18n("Forget")
        icon.name: "edit-clear-history"
        enabled: cfg_maxDown > 0 || cfg_maxUp > 0
        onClicked: { cfg_maxDown = 0; cfg_maxUp = 0; }
    }
    QQC2.Label {
        text: i18n("A speed test teaches the angelfish your line's speed. Copies to other machines on your own network count too; if one sets a record your internet can't reach, forget it here.")
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

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: captionCheck
        Kirigami.FormData.label: i18n("Name tag:")
        text: i18n("Show a name tag under the angelfish")
    }
    QQC2.TextField {
        id: captionField
        enabled: captionCheck.checked
        placeholderText: cfg_device ? links.labelOf(cfg_device) : "Network"
    }

    QQC2.CheckBox {
        id: backgroundCheck
        Kirigami.FormData.label: i18n("Background:")
        text: i18n("Show widget background")
    }
}
