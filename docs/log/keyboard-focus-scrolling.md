# Reveal keyboard-focused controls

## Reproduction and cause

At Largest text in a minimum-size window, a synthetic long speaker name wrapped
correctly in Overview and Audio. However, pressing Tab four times from the Audio
tab focused the first speaker preference below the viewport without scrolling it
into view. Accessibility reported focus, while the screenshot showed no visible
control or focus ring. This made ordinary keyboard operation difficult.

A private AppKit probe using the production `DisplayPanel` reproduced the failure
without showing a window: focus was accepted, but the popup was outside its clip.
The permanent native regression failed before the fix with
`Keyboard focus must reveal an offscreen control`. The missing behavior was
focus-driven scrolling, not text clipping or a stale status report.

## Change

After AppKit accepts a focus change, the main panel reveals a focused `NSControl`
inside a scroll view, with a small margin for its focus ring. It uses AppKit's
[scrollToVisible](https://developer.apple.com/documentation/appkit/nsview/scrolltovisible(_:))
minimum-distance operation after layout. Ordinary refreshes do not reset scrolling.
No controller command, preference value, or hardware policy changed.

## Validation and limits

- `./scripts/verify --native` exited 0: 297 Python tests, native builds/self-tests
  and publication checks passed. Only a test comment changed afterward.
- The native regression now passes; repeating focus on a visible control and
  clearing focus preserve the scroll position. The test never presents a window.
- The original current-source demo at Largest/minimum now reveals the first and
  last Audio preferences with visible focus rings. Command-R preserves the final
  preference's focus and scroll position. Six Shift-Tab steps reveal the upper
  Preserve output button again.
- Synthetic captures 26–29 remain in the ignored UI audit directory. Private
  long-name fixtures and the minimized probe remain in clearly named debug folders.

This checks a long audio-output name, forward/reverse Audio traversal and refresh.
It does not qualify every tab/dialog, actual VoiceOver speech, high contrast,
arbitrary display names, or hardware. No installation, playback, setting mutation,
or actual clipboard access occurred.
