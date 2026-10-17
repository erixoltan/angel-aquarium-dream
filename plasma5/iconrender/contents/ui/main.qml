import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0

// Plasma 5 host for the icon render: just shows dev/IconRender.qml.
Item {
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    Plasmoid.fullRepresentation: IconRender {
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
    }
}
