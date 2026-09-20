# Software-only installer preflight

Add an optional `--preflight` entry point before any installer state mutation. Report
platform/version, selected Python, required source entry points, bounded Xcode tool discovery
and known service namespace conflicts. Output is structured and contains no discovered local
paths. Unsupported prerequisites exit nonzero; capture flags conflict with this option.

This is not a hardware dry run or enrollment approval. Explicitly leave ownership, recovery,
configuration, permissions and physical behavior unqualified. Existing installation checks
remain authoritative. No persistent state or runtime module is added; rollback is source-only.
