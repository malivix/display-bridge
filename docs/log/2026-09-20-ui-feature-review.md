# UI review and next-feature plan

Reviewed source 80cfb8d and freshly captured the isolated demo Overview, Audio, Controls,
and Displays views, including Largest status text. Confirmed the controls/text sizing gap;
recorded source evidence and accessibility/physical limits. Compared current primary vendor
sources for BetterDisplay, MonitorControl, Lunar, BenQ Display Pilot 2 and displayplacer.

Updated the stale roadmap sequence and added a concrete acceptance/rollback plan. Next:
whole-interface readability, then named orientation-specific size presets, recovery/history,
and guided setup. Existing source features are not counted as missing functionality.

Validation: 192 isolated Python tests passed; latest existing GitHub Verify run for 80cfb8d
passed. Documentation-only changes; no native code, runtime configuration, installation or
hardware writes. Screenshots use synthetic state and remain ignored/private. Physical
qualification and installed-source parity remain separate work.
