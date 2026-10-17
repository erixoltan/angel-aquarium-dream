import QtQuick 2.15
import org.kde.plasma.configuration 2.0

// Registers the settings pages. `source` paths are relative to contents/ui/.
ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "memory"
        source: "configGeneral.qml"
    }
}
