function transparentize(color, amount) {
    var c = Qt.color(color)
    return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, 1 - Number(amount || 0))))
}

function mix(a, b, amount) {
    var ca = Qt.color(a), cb = Qt.color(b), t = Math.max(0, Math.min(1, Number(amount || 0)))
    return Qt.rgba(ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t,
                   ca.b + (cb.b - ca.b) * t, ca.a + (cb.a - ca.a) * t)
}
