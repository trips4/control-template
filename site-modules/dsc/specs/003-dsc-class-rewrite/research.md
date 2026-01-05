# Research: DSC Class Reimplementation

**Feature**: 003-dsc-class-rewrite  
**Date**: 2025-12-16  
**Status**: Complete

## Overview

This document consolidates research findings for reimplementing the DSC class installation logic. The existing implementation (from feature 002) has the right structure but needs refinement for robustness, error handling, and edge cases identified in the specification.

## Research Areas

### 1. DSC v3 Installation Methods

**Objective**: Determine the most reliable approach for downloading and installing DSC v3 binaries across platforms.

**Findings**:

- **GitHub Releases**: DSC v3 is distributed via GitHub releases at `https://github.com/PowerShell/DSC/releases`
- **Asset Naming**: Format is `DSC-{arch}-{platform}.{ext}` where:
  - `arch`: x86_64 or aarch64
  - `platform`: windows, apple-darwin, unknown-linux-gnu
  - `ext`: zip (Windows) or tar.gz (Unix)
- **Latest vs Versioned**: `/latest/download/` for latest, `/download/{version}/` for specific versions
- **Binary Structure**: Archive contains `dsc` (or `dsc.exe`) binary directly

**Decision**: Use direct GitHub release downloads via `Invoke-WebRequest` (Windows) or `curl` (Unix). This is already implemented correctly in the existing code.

**Alternatives Considered**:
- Package managers (chocolatey, apt, brew): Not officially supported for DSC v3
- Building from source: Unnecessary complexity for end users
- Embedding binaries in module: Increases module size significantly

---

### 2. Custom Fact Implementation for Path Discovery

**Objective**: Research best practices for Puppet custom facts to expose DSC installation path to the provider.

**Findings**:

- **External Facts Pattern**: The existing implementation uses external facts (JSON files) written by the manifest
- **Fact File Location**: Platform-specific:
  - Windows: `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json`
  - Unix: `/etc/puppetlabs/facter/facts.d/dsc_install.json`
- **Custom Fact Ruby Code**: `lib/facter/dsc_install_path.rb` reads the JSON file and exposes the `dsc_install_path` fact
- **Two-Run Pattern**: First run writes the fact file, second run uses the fact (standard Puppet pattern for external facts)

**Decision**: Keep the external facts pattern from feature 002. It's proven, reliable, and follows Puppet best practices. The custom fact implementation is already correct.

**Rationale**:
- External facts survive Puppet runs and are available system-wide
- JSON format is easily readable and maintainable
- Puppet agent automatically loads external facts on subsequent runs
- No need for complex catalog lookups or parameter passing

**Alternatives Considered**:
- Ruby custom fact only (no external file): Would require the fact to inspect the catalog, which is complex and fragile
- Environment variables: Less reliable across Puppet runs and user contexts
- Configuration files outside Puppet: Breaks the single-source-of-truth principle

---

### 3. Idempotency and Error Handling

**Objective**: Ensure the DSC class doesn't re-download or re-extract when DSC is already installed, and handles failures gracefully.

**Findings**:

- **`creates` Parameter**: Puppet's `exec` resource supports `creates` which checks if a file exists before running
- **Current Implementation**: Uses `creates => "${actual_install_dir}/${dsc_binary}"` which prevents re-downloads
- **Gap Identified**: No validation that the binary is actually functional (could be corrupted)
- **Error Propagation**: Exec failures will cause Puppet run to fail, which is correct behavior

**Decision**: Add a validation step after extraction to verify the DSC binary responds to `--version` or similar check. This catches corrupted downloads or installation issues.

**Implementation**: Add an `exec` resource that runs `dsc --version` with `unless` that succeeds if the binary works. This provides early error detection.

**Alternatives Considered**:
- File checksum validation: DSC releases don't publish checksums consistently
- Version comparison: Adds complexity for minimal benefit in the "install if missing" use case
- No additional validation: Risk of silent failures if binary is corrupted

---

### 4. Cross-Platform PATH Management

**Objective**: Research how to reliably add DSC to the system PATH on each platform, if `manage_path => true`.

**Findings**:

- **Windows**: `windows_env` module (puppetlabs/windows_env) provides the `windows_env` resource type for PATH management
- **Unix**: Profile scripts in `/etc/profile.d/` are sourced by most shells
- **Current Implementation**: Correctly uses both approaches
- **Gap**: PATH changes don't take effect until next shell session/login

**Decision**: Keep existing PATH management approach but clarify in documentation that PATH changes require new shell sessions. This is standard behavior and not something Puppet can change.

**Alternatives Considered**:
- Modifying ~/.bashrc or ~/.zshrc: Too user-specific, won't work for all users
- System-wide /etc/environment: Not supported on all distributions
- Not managing PATH at all: Would force users to always specify full paths

---

### 5. Custom Installation Directory Handling

**Objective**: Ensure custom `install_dir` parameter works correctly with the custom fact and provider.

**Findings**:

- **Parameter Handling**: `pick($install_dir, $default_install_dir)` correctly uses custom value or falls back to default
- **Fact File Content**: The `dsc_install.json` file records `$actual_install_dir` (which includes custom overrides)
- **Provider Integration**: Provider reads `Facter.value(:dsc_install_path)` which comes from the fact file
- **Flow Verification**: Custom path → written to fact file → custom fact exposes it → provider uses it ✓

**Decision**: The existing implementation correctly handles custom installation directories end-to-end. No changes needed to the parameter flow.

---

### 6. Platform Detection and Defaults

**Objective**: Verify platform detection logic and default paths are appropriate.

**Findings**:

- **Kernel Fact**: `$facts['kernel']` reliably returns 'windows', 'Linux', or 'Darwin'
- **Architecture Detection**: `$facts['os']['architecture']` provides architecture string that maps to GitHub asset names
- **Default Paths**:
  - Windows: `C:/Program Files/DSC` (standard program files location)
  - Linux: `/opt/dsc` (follows FHS for optional software)
  - macOS: `/usr/local/dsc` (standard for user-installed software)

**Decision**: Keep existing defaults. They follow platform conventions and match DSC v3 documentation recommendations.

**Alternatives Considered**:
- Windows: `C:/ProgramData/DSC` (app data location) - Not appropriate for executables
- Linux: `/usr/local/bin/` - Better for PATH but complicates directory management
- Consolidating paths: Reduces testing surface but violates platform conventions

---

### 7. Upgrade and Version Management

**Objective**: Determine how to handle DSC upgrades and version changes.

**Findings**:

- **Current Behavior**: `creates` parameter prevents re-installation if binary exists
- **Version Parameter**: Class accepts `$version` but doesn't enforce it if DSC already installed
- **Gap**: No mechanism to force upgrade when version parameter changes

**Decision**: Document that version changes require manual DSC removal or don't use `creates`. The "install if missing" pattern is simpler and matches most Puppet module conventions. Full version enforcement is out of scope (per spec).

**Rationale**:
- Automatic upgrades risk breaking existing DSC configurations
- Users can explicitly remove DSC if they need a different version
- Most users will use `version => 'latest'` and upgrade via module updates

---

### 8. Error Messages and User Experience

**Objective**: Ensure error messages are clear and actionable when installation fails.

**Findings**:

- **Puppet Exec Failures**: `logoutput => true` captures command output in Puppet logs
- **Download Failures**: Network errors, 404s, auth failures all propagate to Puppet run failure
- **Permission Errors**: Directory creation or file extraction failures stop the run with stack trace

**Decision**: Add custom failure messages using `fail()` function at critical points (architecture detection, platform detection, post-installation validation).

**Implementation**: Wrap critical logic with validation and meaningful error messages like:
- "DSC installation failed: Downloaded binary is not functional. Check network connectivity."
- "Unsupported platform: DSC v3 requires Windows 10+/Server 2019+, modern Linux, or macOS 12+"

---

## Summary of Decisions

| Area | Decision | Implementation Status |
|------|----------|----------------------|
| Installation Method | GitHub releases via curl/Invoke-WebRequest | ✅ Implemented |
| Path Discovery | External facts + custom Ruby fact | ✅ Implemented |
| Idempotency | Use `creates` parameter + add binary validation | ⚠️ Needs validation step |
| PATH Management | windows_env + profile.d scripts | ✅ Implemented |
| Custom Directories | Use `pick()` with fact file recording | ✅ Implemented |
| Platform Defaults | Windows: C:/Program Files/DSC, Linux: /opt/dsc, macOS: /usr/local/dsc | ✅ Implemented |
| Version Management | Install-if-missing pattern, no forced upgrades | ✅ Implemented (by design) |
| Error Handling | Add validation + clear error messages | ⚠️ Needs improvement |

## Implementation Priorities

Based on this research, the reimplementation should focus on:

1. **HIGH**: Add DSC binary validation after installation
2. **HIGH**: Improve error messages at failure points  
3. **MEDIUM**: Add better documentation comments in code
4. **LOW**: Consider adding example of version pinning in examples/

The existing architecture from feature 002 is sound. This rewrite is about refinement, not fundamental restructuring.
