// Whether a key event's text is something a person typed, rather than the
// control character a key like Enter ("\r") or Escape ("\x1b") also reports.
// Only typed text may start a search or extend the query. Both Unicode control
// ranges are rejected: C0 with DEL, and C1 (U+0080-U+009F), so non-ASCII input
// is allowed without letting a control character such as U+0085 through.
function isTypedText(text) {
    const value = String(text ?? "");
    if (value.length === 0)
        return false;
    for (let i = 0; i < value.length; ++i) {
        const code = value.charCodeAt(i);
        if (code < 0x20 || (code >= 0x7f && code <= 0x9f))
            return false;
    }
    return true;
}
