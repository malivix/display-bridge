# Keyboard access to More controls

Command-Shift-P opens the existing controls menu from any main-window tab. It uses the
same refreshed menu and command dispatch as the More controls button. The existing
window handler excludes modal dialogs, attached sheets and non-key windows; repeated
keypresses and extra modifiers are rejected. No global event monitor or permission added.

Native regressions cover the chord, case/Caps Lock handling, repeats and modifier
rejection. `scripts/verify --native` passed, including all 296 Python tests and native
self-tests. In a new signed demo, the shortcut opened the controls menu, Escape dismissed
it, and Command-3 selected Displays afterward. While the preset-name modal was open, the
shortcut left that dialog and its text focus intact. Escape closed it without saving.

The UI check used synthetic ready state at Standard size; existing menu rendering was
reused. It does not qualify every menu item or VoiceOver speech. No real command, installed
service, monitor, notification or clipboard state changed.
