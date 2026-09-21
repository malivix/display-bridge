# Installer package after the size-module extraction

Built a fresh, private standalone setup app from clean committed source `6022dc7` using
`setup_gui.py --build-only`. Its embedded revision matched that commit, Demo was false,
and the source snapshot included the new SizeChooser module. Building did not launch
or activate the installer.

The setup binary's isolated self-tests passed. Running the bundled source's `scripts/test`
with Python bytecode disabled passed all 290 tests. Its software-only Mac A preflight
passed. Strict deep code-signature verification passed before and after bundled tests and
preflight; the embedded source contained no Python cache directories afterward.

Live installation eligibility was checked separately and remained unresolved due to
unknown input ownership. No mapping was changed and no installation, routing or display
mutation was attempted. Raw status and package paths remain private. Packaging checks
prove source/seal consistency, not successful service activation or physical behavior.
The installation guide also removes an obsolete statement that graphical setup is only
planned; it distinguishes software review from live enrollment inspection.
