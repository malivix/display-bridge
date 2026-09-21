# SPDX-License-Identifier: MIT
"""Canonical installed file inventory, shared by deployment and health checks."""

VERSION = "2.10.2"
MENU_BUILD = "2102"

# One source inventory for menu installation, prerequisite checks and native verification.
MENU_SOURCES = (
    "native/menu/main.swift",
    "native/menu/Commands.swift",
    "native/menu/MonitorResults.swift",
    "native/menu/HealthReport.swift",
    "native/menu/EnrollmentReview.swift",
    "native/menu/InstallationReport.swift",
    "native/menu/ListeningCheck.swift",
    "native/menu/Presentation.swift",
    "native/menu/PresetWindows.swift",
    "native/menu/MenuApp.swift",
    "native/menu/SelfTests.swift",
)

RUNTIME_MODULES = (
    "display-auto.py",
    "audio_policy.py",
    "command_results.py",
    "display_snapshot.py",
    "support_summary.py",
    "recovery_state.py",
    "observability.py",
    "hidpi_report.py",
    "health_check.py",
    "install_progress.py",
    "persisted_state.py",
    "ddc_log_report.py",
    "monitor_controls.py",
    "brightness_presets.py",
    "scaling_choices.py",
    "size_presets.py",
    "scaling_proposal.py",
    "scaling_preview.py",
    "preview_runner.py",
    "preview_hardware.py",
    "preview_service.py",
    "release_manifest.py",
)
HELPER_HASH_FIELDS = {
    "display-layout": "helper_sha256",
    "display-audio": "audio_sha256",
    "display-ddc": "m1ddc_sha256",
    "display-rotate": "rotate_sha256",
    "display-mode-info": "mode_info_sha256",
}
INSTALLED_FILES = (*RUNTIME_MODULES, *HELPER_HASH_FIELDS)


def source_fingerprint(package):
    """Portable controller/menu source identity, not a binary signature."""
    import hashlib
    import json
    files = sorted(set(RUNTIME_MODULES + MENU_SOURCES))
    hashes = {name: hashlib.sha256((package / name).read_bytes()).hexdigest() for name in files}
    return hashlib.sha256(json.dumps(hashes, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
