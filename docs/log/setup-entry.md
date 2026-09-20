# Discoverable setup review

Added Setup readiness to the top-level menu and a Review this Mac action beside the setup
report. The enrollment report uses the same explicit action name instead of Refresh; its
instructions distinguish inspection from enrollment saving. The existing bounded controller
command and explicit host-choice dialog remain authoritative. No new mutation endpoint.

Validated the menu-to-setup-to-review sequence in the isolated demo at Largest text. The
complete dialog fit, host choice started empty with review disabled, and Escape returned to
the retained setup report. All 247 Python tests and native builds/self-tests passed. Reviewed
and scanned the staged changes for privacy. No hardware, installed release or service changes.
Mutable graphical capture/activation and physical setup qualification remain separate work.
