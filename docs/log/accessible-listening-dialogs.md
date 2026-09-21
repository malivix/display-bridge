# Enlarged listening dialogs

Replaced the two system-sized listening alerts with native panels that use the selected app
font size for text and buttons. Cancel is initially focused before playback; Not sure is the
initial observation. Escape/close cancels playback or yields an uncertain observation. The
listening decoder and panels now live in ListeningCheck.swift, registered in MENU_SOURCES.

The demo exercises the same panels with explicit synthetic wording and never dispatches
playback. At Largest, verified cancellation with Escape, Tab to Continue demo, Space to open
the response dialog, all response buttons fitting, and Escape yielding only a synthetic
uncertain past observation. The app does not persist or upload the response.

All 258 Python tests and native builds/self-tests passed; after adding the explicit Escape
handler, rebuilt and reran native self-tests. Staged privacy checks passed. No actual playback,
installed update or physical audibility claim. Full VoiceOver and real listening qualification
remain separate.
