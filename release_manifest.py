# SPDX-License-Identifier: MIT
"""Canonical installed file inventory, shared by deployment and health checks."""
RUNTIME_MODULES = (
    'display-auto.py', 'audio_policy.py', 'recovery_state.py', 'observability.py',
    'hidpi_report.py', 'health_check.py', 'persisted_state.py', 'ddc_log_report.py',
    'monitor_controls.py', 'scaling_choices.py', 'scaling_proposal.py',
    'scaling_preview.py', 'preview_runner.py', 'preview_hardware.py',
    'preview_service.py', 'release_manifest.py',
)
HELPER_HASH_FIELDS = {
    'display-layout': 'helper_sha256',
    'display-audio': 'audio_sha256',
    'display-ddc': 'm1ddc_sha256',
    'display-rotate': 'rotate_sha256',
    'display-mode-info': 'mode_info_sha256',
}
INSTALLED_FILES = (*RUNTIME_MODULES, *HELPER_HASH_FIELDS)
