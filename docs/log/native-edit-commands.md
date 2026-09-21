# Native text editing commands

The menu app now installs a shared AppKit Edit menu using standard responder-chain
Select All, Cut, Copy and Paste actions. Missing menu actions caused Command–A to do
nothing in the numeric modal even while its text editor remained focused. No custom
key monitor, accessibility permission or clipboard implementation was introduced.
Demo mode includes Select All only, retaining its clipboard restriction.

The UI reproduction typed 75, pressed Command–A, then typed 20: the previous demo
produced 7520; the new build produced 20 with a matching slider and enabled Apply.
This exercises actual modal keyboard routing through computer use, not a synthetic
function call. The final demo clipboard filtering was added after that comparison;
Select All uses the same action in both modes. Cut/Copy/Paste were not exercised
against the user's general clipboard. No hardware commands were dispatched.

Validation: `scripts/verify --native` passed on the final source, including the demo
clipboard filter: 290 Python tests and native builds/self-tests. These checks do not
qualify all keyboard workflows.
The new source is listed in the canonical menu build inventory. No installation.
