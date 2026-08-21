pragma Singleton
import QtQuick
import "." as Local

QtObject {
    readonly property QtObject colors: QtObject {
        property color colLayer1: "#22252b"
        property color colLayer1Hover: "#30343c"
        property color colLayer2: "#2c3038"
        property color colLayer2Hover: "#3a404b"
        property color colLayer2Active: "#4b596e"
        property color colOnLayer1: "#f2f4f7"
        property color colSurfaceContainerLow: "#20242a"
        property color colSurfaceContainer: "#272c34"
    }
    readonly property QtObject font: QtObject {
        readonly property QtObject pixelSize: QtObject {
            property int smaller: 13
            property int small: 14
            property int normal: 16
        }
    }
    readonly property QtObject rounding: QtObject {
        property int small: 12
        property int large: 20
        property int verysmall: 6
    }
    readonly property QtObject animation: QtObject {
        readonly property QtObject elementMoveEnter: QtObject {
            readonly property QtObject numberAnimation: QtObject { function createObject(parent) { return null } }
        }
        readonly property QtObject elementMoveFast: QtObject {
            readonly property QtObject numberAnimation: QtObject { function createObject(parent) { return null } }
        }
    }
}
