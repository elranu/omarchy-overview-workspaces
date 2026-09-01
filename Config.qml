pragma Singleton
import QtQuick

QtObject {
    readonly property QtObject options: QtObject {
        readonly property QtObject overview: QtObject {
            property bool enable: true
            property int columns: 5
            property bool centerIcons: true
            property bool orderRightLeft: false
            // Cada overlay muestra solo los workspaces de SU monitor. Con false
            // las dos pantallas dibujan la grilla completa y ves los workspaces
            // del otro monitor repetidos en ambas.
            property bool perMonitor: true
        }
        readonly property QtObject background: QtObject { property string wallpaperPath: ""; property string thumbnailPath: "" }
        readonly property QtObject hacks: QtObject { property int arbitraryRaceConditionDelay: 50 }
    }
}
