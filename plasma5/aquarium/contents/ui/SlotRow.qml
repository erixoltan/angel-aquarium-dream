import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.5 as Kirigami

// One fish slot on the settings page: shown or not, which device (when there's a choice), and
// the name on its tag. A separate file because Qt 5.15 inline components can't see the page.
RowLayout {
    id: row
    property alias on: check.checked
    property alias name: nameField.text
    property string device: ""
    property string defaultName: ""
    property var choices: null          // [{ text, value }], or null for no device choice

    QQC2.CheckBox { id: check }
    QQC2.ComboBox {
        id: deviceBox
        visible: !!row.choices
        enabled: check.checked
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        model: row.choices || []
        textRole: "text"
        valueRole: "value"
        // re-find the stored device whenever the list changes (drives and GPUs load late)
        currentIndex: row.choices ? Math.max(0, indexOfValue(row.device)) : -1
        onActivated: row.device = currentValue
    }
    // no device to pick: keep its space, so every name field lines up
    Item {
        visible: !row.choices
        Layout.preferredWidth: deviceBox.Layout.preferredWidth
    }
    QQC2.TextField {
        id: nameField
        enabled: check.checked
        placeholderText: row.defaultName
        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
    }
}
