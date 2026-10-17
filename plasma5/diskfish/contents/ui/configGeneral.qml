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
    property real cfg_maxRead
    property real cfg_maxWrite

    function rate(bytesPerSecond) {
        return bytesPerSecond >= 1e9 ? (bytesPerSecond / 1e9).toFixed(1) + " GB/s"
             : Math.round(bytesPerSecond / 1e6) + " MB/s";
    }

    DiskList { id: disks }

    QQC2.Label {
        text: i18n("The angelfish eats what is written to the drive and blows bubbles as it is read. Its sweater stripes fill with all traffic, gold for the writing part and orange for the reading. The collar fills with the drive itself; when it is nearly full the halo appears. It turns red near the drive's own warning temperature and grows wings near its critical one.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: deviceBox
        Kirigami.FormData.label: i18n("Drive:")
        readonly property var choices: {
            var out = [{ text: i18n("All drives"), value: "" }];
            for (var i = 0; i < disks.ids.length; i++)
                out.push({ text: disks.names[i], value: disks.ids[i] });
            return out;
        }
        model: choices
        textRole: "text"
        valueRole: "value"
        currentIndex: Math.max(0, indexOfValue(cfg_device))
        // the fastest rates belong to the drive they were seen on
        onActivated: if (currentValue !== cfg_device) { cfg_device = currentValue; cfg_maxRead = 0; cfg_maxWrite = 0; }
    }
    QQC2.Label {
        text: i18n("For an angelfish per drive, add one for each.")
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.Label {
        Kirigami.FormData.label: i18n("Fastest so far:")
        text: cfg_maxRead > 0 || cfg_maxWrite > 0
            ? i18n("read %1   write %2", rate(cfg_maxRead), rate(cfg_maxWrite))
            : i18n("not learned yet")
    }
    QQC2.Button {
        text: i18n("Forget")
        icon.name: "edit-clear-history"
        enabled: cfg_maxRead > 0 || cfg_maxWrite > 0
        onClicked: { cfg_maxRead = 0; cfg_maxWrite = 0; }
    }
    QQC2.Label {
        text: i18n("Copying a large file teaches the angelfish your drive's speed.")
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
        placeholderText: "Disk"
    }

    QQC2.CheckBox {
        id: backgroundCheck
        Kirigami.FormData.label: i18n("Background:")
        text: i18n("Show widget background")
    }
}
