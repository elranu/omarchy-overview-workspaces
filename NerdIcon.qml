import QtQuick

Text {
    id: root

    property string symbol: "apps"
    property real iconSize: 18

    function glyphFor(name) {
        switch (String(name || "apps")) {
        case "add": return "\uDB80\uDC2F";           // mdi-plus
        case "apps": return "\uF00A";                // fa-th-large
        case "select_window": return "\uF24D";       // fa-object-group
        case "terminal": return "\uF120";            // fa-terminal
        case "search": return "\uF002";              // fa-search
        case "menu": return "\uF0C9";                // fa-bars
        case "logout": return "\uF08B";              // fa-sign-out
        case "restart_alt":
        case "refresh": return "\uF021";             // fa-refresh
        case "power_settings_new": return "\uF011";  // fa-power-off
        default: return "\uF00A";                     // fa-th-large
        }
    }

    text: root.glyphFor(root.symbol)
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font {
        family: "JetBrainsMono Nerd Font"
        pixelSize: root.iconSize
    }
}
