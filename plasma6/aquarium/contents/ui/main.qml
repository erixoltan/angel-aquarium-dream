import QtQuick
import org.kde.plasma.plasmoid

// Plasma 6 wallpaper: the aquarium (Aquarium.qml, shared with the Plasma 5 version). A Plasma 6
// wallpaper's root must be a WallpaperItem, which holds the settings Plasma 5 called
// `wallpaper.configuration`.
WallpaperItem {
    id: wallpaperRoot

    Aquarium {
        anchors.fill: parent
        cfg: wallpaperRoot.configuration
    }
}
