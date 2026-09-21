# Live preset name validation

The save dialog previously enabled Save with an empty name, leaving validation until
submission. It now uses the existing name validator while editing, disables Save for
invalid names, and gives a neutral initial hint. Submission validation remains in place;
size and brightness saves share the form. Removal behavior is unchanged.

Validation: `scripts/verify --native` passed, including 290 Python tests and isolated
native self-tests. A newly built, ad-hoc-signed demo was inspected at Largest text:
empty name disabled Save; `Reading` enabled it; trailing whitespace disabled it and
explained why; Command-A replacement restored eligibility; Escape closed without saving.
No display, audio, clipboard or installed-controller change was made. Accessibility-tree
feedback was checked; VoiceOver speech and the full appearance matrix were not tested.
