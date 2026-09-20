# Private pasteboard integration check

Extracted the summary writer used by the menu so the actual AppKit copy path can be tested
without changing the general clipboard. Empty and oversized input is rejected before
clearing the destination. The opt-in `--test-private-pasteboard` path creates a unique
named board, checks exact Unicode round-trip and preservation after rejected inputs,
releases it and exits before app startup.

Validation: a freshly compiled executable passed the real private-pasteboard integration
check on the development Mac. `scripts/verify --native` passed 232 Python tests and all
native builds/self-tests. This verifies the copy API used by the feature, supplementing
the earlier source-selection and demo checks; the normal clipboard and installed software
were untouched. General-clipboard permission behavior remains environment-dependent.
