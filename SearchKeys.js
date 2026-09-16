// Whether a key event's text is something a person typed, rather than the
// control character a key like Enter ("\r") or Escape ("\x1b") also reports.
// Only typed text may start a search or extend the query.
function isTypedText(text) {
    const value = String(text ?? "");
    if (value.length === 0)
        return false;
    for (let i = 0; i < value.length; ++i) {
        const code = value.charCodeAt(i);
        if (code < 0x20 || code === 0x7f)
            return false;
    }
    return true;
}
