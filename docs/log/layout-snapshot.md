# Observed logical layout in Displays

The read-only mode helper now reports CoreGraphics mirror-source IDs. The snapshot checks
IDs and relationships across both inspections, then replaces raw IDs with enrolled roles.
Missing, cyclic, self-referential, external or invalid relationships report unknown.
Input ownership is separate from this Mac's logical desktop relationship, including when
both monitors show another Mac. No mutation or periodic polling was added.

Displays presents an accessible text schematic, source/destination explanation, input
ownership and measured macOS rotation above the existing current/saved mode details.
It is explicitly a snapshot, not physical placement or inspection of another computer.
Older helper output remains readable with topology marked unavailable.

Validation: `scripts/verify --native` passed 223 Python tests and native builds/self-tests.
Regressions cover both mirror directions, independent desktops, invalid/missing topology,
relationships changing between reads, and unfamiliar UI data. A rebuilt hardware-free
demo was inspected through Command-3/Command-R and at Largest text size: the schematic,
ownership labels and rotation wrapped without clipping. Physical topology and full
VoiceOver qualification remain pending. No installed helper/menu/controller was changed.
