# Main-window keyboard navigation

Added window-scoped Command 1–5 tab selection and Command R contextual refresh. The
window handles only exact Command combinations (Caps Lock does not interfere) and
ignores repeat events. No event tap, global monitor or new permission is involved.
Modal windows and attached sheets keep their own behavior. A tab tooltip and accessibility
help describe the shortcuts.

Refresh routes through existing read-only commands or local state refresh. Monitor reads
use the selected role and existing availability guard; busy commands cannot be duplicated.
Refresh arguments are explicitly allowlisted, so selecting a report does not turn refresh
into a repair or settings write. Persistence and hardware policy are unchanged.

Validation: 214 Python tests plus all native builds/self-tests passed. Pure cases cover
modifiers, Caps Lock, unknown keys, repeats, report allowlisting and exact monitor target.
Demo keyboard inspection confirmed Command 3 → Displays, Command R → synthetic mode
snapshot, subsequent Tab focus in the view, and Command 1 during a preview dialog leaving
the underlying Displays tab unchanged after Escape. No real monitor read/write occurred.
Full keyboard/VoiceOver qualification of every control remains open. Not installed.
