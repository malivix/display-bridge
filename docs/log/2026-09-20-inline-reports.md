# Read diagnostic reports in the main window

Details now combines live status with explicitly refreshed health, timing, DDC and support
reports. Existing menu/footer report commands route into this tab. Snapshot text survives
normal status refresh, carries a timestamp and remains selectable/scrollable at the app's
chosen text size. A separate status label retains command progress while a report is open.
No new background hardware polling or persistence was added.

Validation: corrected a duplicate local name caught by compilation. Fresh demo inspection
at minimum window size/Largest confirmed selector, explicit refresh, snapshot rendering,
scrolling and retention across the live timer. Demo report content is explicitly synthetic
and never invokes hardware or reads diagnostics. Contextual accessibility labels identify
the selected report; full VoiceOver navigation remains unqualified. No installation occurred.

Final validation: 207 Python tests and native builds/self-tests passed on the final source.
