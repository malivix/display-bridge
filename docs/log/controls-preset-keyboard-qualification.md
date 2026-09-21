# Controls, presets and Details keyboard qualification

Checked the production UI behavior committed in `4d33309`, using the same private
demo build as the focus-scrolling fix. The only presentation fixture difference
is a deliberately long synthetic selected-output name. Largest text and the
minimum main-window size were retained; dialogs opened at their default sizes.

| Path | Observed result |
| --- | --- |
| Controls → eight Tab steps | Brightness presets receives focus and scrolls into view with a visible ring. |
| Space → brightness preset chooser | Selector is initially focused; explanation and all actions fit at Largest. |
| Two Tab steps → Space | Save current brightness dialog opens with focus in the name field. |
| Enter a long valid name → Tab | Full name is visible, replacement checkbox receives focus, and Save becomes enabled. No save was submitted. |
| Escape from brightness save | Returns to Controls with focus on the Brightness presets button. |
| Displays → Save current size | Keyboard opens the size-save dialog with focus in the name field. |
| Enter a leading-space name → Tab | Specific whitespace error appears; Save stays disabled. The next Tab reaches Cancel. |
| Escape from size save | Returns to Displays with focus on Save current size. |
| Details → Tab traversal | Report selector, Refresh, More controls, Health, Diagnostics and selectable report are reachable. |
| Command-Down in report | Scrolls to the end while retaining report focus; final explanation is readable. |

No new defect was observed in these paths. Private captures 30 and 31 show the
long valid brightness name and invalid size-name keyboard state. No command was
submitted, no preset was saved, and no hardware, playback, clipboard or installation
operation occurred. The demo command boundary remained active.

This does not qualify every dialog, minimum dialog sizes, VoiceOver speech,
high contrast, mouse-free interaction with all popup choices, or physical command
outcomes. No source changed, so the existing native verification for `4d33309`
remains the code-test evidence; these observations extend interaction evidence only.
