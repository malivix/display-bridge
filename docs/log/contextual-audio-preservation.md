# Contextual audio preservation

The Audio tab puts temporary output preservation immediately below the selected output.
One button offers Preserve output for 30 minutes, or Resume automatic audio while a saved
preservation deadline is active. The expiry stays beside the action; repair and listening
checks follow. This uses the existing commands and leaves headset preservation and repair
policy unchanged. Saved intent is not presented as proof of routing or audibility.

Validation: `scripts/verify --native` passed, including 290 Python tests and native checks.
Native cases cover active/expired preservation, missing controls and a non-finite deadline.
A fresh demo at Largest text and minimum window size showed the expiry and Resume together,
with Repair disabled and its existing explanation visible. No route or playback command ran.
The new audio-manual demo fixture always supplies a synthetic deadline 15 minutes ahead;
it is a layout fixture, not a countdown/expiry integration test. Expiry selection is model-tested.
No installed release changed; physical routing and full accessibility remain separately qualified.
