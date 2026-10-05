# Changelog

All notable changes to this project are documented in this file.

The format follows a simple version history based on the project's development stages.

---

## [Unreleased]

### Added

- PowerShell automation for cleaning Microsoft 365 / Microsoft Office components and residual configurations.
- Administrative privilege verification.
- Automatic shutdown of running Microsoft Office applications.
- Microsoft Office service shutdown.
- Microsoft Office Click-to-Run detection and product removal.
- Legacy MSI Office installation detection and removal.
- Removal of Office-related scheduled tasks.
- Removal of the `ClickToRunSvc` service when still present.
- Cleanup of residual Office directories.
- Registry backup before Office policy cleanup.
- Removal of residual Office policy registry paths.
- Removal of remaining Click-to-Run registry configurations.
- Cleanup of Office-related temporary files.
- Final verification of selected Click-to-Run components.
- Optional Windows restart after the cleanup process.

### Changed

- Improved the script description to avoid implying that every Office component is guaranteed to be removed.
- Improved the final success message to indicate that the cleanup process was completed rather than claiming absolute removal.
- Improved comments and documentation around Office policy cleanup.
- Added an explanatory comment for the PowerShell execution policy configuration.
- Documented that `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` applies only to the current PowerShell session and does not permanently modify the Windows execution policy.
- Expanded project documentation with a complete README.
- Added documentation describing the original Microsoft 365 installation error that motivated the project.
- Added project structure and workflow documentation.
- Added warnings for corporate-managed environments and administrative use.

### Documentation

- Added `README.md`.
- Added `LICENSE` using the MIT License.
- Added the original installation error screenshot under `docs/images/`.
- Added usage instructions, limitations, registry backup information and contribution guidelines.

---

## [0.1.0] - Initial Development

### Added

- Initial PowerShell cleanup workflow created from a real Microsoft 365 installation troubleshooting scenario.
- Initial Office Click-to-Run cleanup logic.
- Initial MSI installation detection.
- Initial Office services and scheduled task cleanup.
- Initial residual file and registry cleanup.
- Initial final verification and optional restart workflow.

---

## Notes

This project is an independent community project created for troubleshooting and automation purposes.

It is not affiliated with or endorsed by Microsoft.

Changes listed under `[Unreleased]` represent the current development state and may be included in a future version release.