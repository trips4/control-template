# Data Model: DSC Class Reimplementation

**Feature**: 003-dsc-class-rewrite  
**Date**: 2025-12-16  
**Status**: Complete

## Overview

This document defines the data structures and state management for the DSC class reimplementation. Since this is primarily installation automation, the "data" consists of configuration parameters, installation state, and the fact file format.

## Entities

### 1. DSC Class Parameters

**Purpose**: Configuration inputs provided by users when declaring the `dsc` class.

**Attributes**:

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `install_dir` | `Optional[Stdlib::Absolutepath]` | No | Platform-specific | Custom installation directory for DSC binary |
| `version` | `String` | No | `'latest'` | DSC version to install (e.g., 'latest', 'v3.1.2') |
| `manage_path` | `Boolean` | No | `true` | Whether to add DSC to system PATH |

**Validation Rules**:
- `install_dir` must be an absolute path if provided
- `version` must match GitHub release tag format or be 'latest'
- `manage_path` must be boolean

**Example**:
```puppet
class { 'dsc':
  install_dir => '/opt/custom/dsc',
  version     => 'v3.1.2',
  manage_path => true,
}
```

---

### 2. Platform Configuration (Derived State)

**Purpose**: Computed values based on the target system's facts, used for platform-specific logic.

**Attributes**:

| Attribute | Source | Possible Values | Description |
|-----------|--------|-----------------|-------------|
| `kernel` | `$facts['kernel']` | 'windows', 'Linux', 'Darwin' | Operating system kernel |
| `architecture` | `$facts['os']['architecture']` | 'x86_64', 'amd64', 'aarch64', 'arm64', etc. | CPU architecture |
| `default_install_dir` | Computed | See defaults below | Platform-specific installation directory |
| `platform_string` | Computed | 'windows', 'unknown-linux-gnu', 'apple-darwin' | GitHub release platform identifier |
| `archive_ext` | Computed | 'zip', 'tar.gz' | Archive file extension for platform |
| `dsc_binary_name` | Computed | 'dsc.exe', 'dsc' | Executable filename for platform |

**Default Installation Directories**:
- Windows: `C:/Program Files/DSC`
- Linux: `/opt/dsc`
- macOS: `/usr/local/dsc`

**Relationships**:
- `kernel` determines `platform_string`, `archive_ext`, and `dsc_binary_name`
- `architecture` maps to GitHub asset architecture string ('x86_64' or 'aarch64')
- `default_install_dir` depends on `kernel`

**Example Computation**:
```puppet
$default_install_dir = case $facts['kernel'] {
  'windows': { 'C:/Program Files/DSC' }
  'Darwin':  { '/usr/local/dsc' }
  'Linux':   { '/opt/dsc' }
  default:   { fail("Unsupported kernel: ${facts['kernel']}") }
}
```

---

### 3. Installation State

**Purpose**: Represents the current state of DSC installation on the system.

**States**:

| State | Condition | Description |
|-------|-----------|-------------|
| Not Installed | DSC binary does not exist at target path | Initial state on clean system |
| Installing | Puppet run in progress, resources being applied | Transient state during first run |
| Installed | DSC binary exists and is functional | Steady state after successful installation |
| Installed (Unmanaged) | DSC exists but fact file missing | DSC installed manually outside Puppet |

**State Transitions**:

```
Not Installed → Installing → Installed
                    ↓
                  Failed (terminal state - requires manual intervention)

Installed (Unmanaged) → Installing → Installed
                          (creates fact file)
```

**Detection Logic**:
- Check file existence: `"${actual_install_dir}/${dsc_binary_name}"`
- Check functionality: `dsc --version` (proposed addition)
- Check fact file: `/etc/puppetlabs/facter/facts.d/dsc_install.json`

---

### 4. External Fact File (`dsc_install.json`)

**Purpose**: Persistent storage of DSC installation path, enabling provider discovery across Puppet runs.

**File Location**:
- Windows: `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json`
- Unix: `/etc/puppetlabs/facter/facts.d/dsc_install.json`

**Format**: JSON

**Schema**:
```json
{
  "dsc_install_path": "<absolute_path_to_directory>"
}
```

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dsc_install_path` | String (absolute path) | Yes | Directory containing DSC binary (not including binary name) |

**Example**:
```json
{
  "dsc_install_path": "/opt/dsc"
}
```

**Validation Rules**:
- Must be valid JSON
- `dsc_install_path` must be an absolute path string
- Path should exist on the filesystem (though fact loads even if it doesn't)

**Lifecycle**:
1. **Creation**: Written by `manifests/init.pp` after successful DSC installation
2. **Reading**: Loaded by Facter on subsequent Puppet runs, exposed as `$facts['dsc_install_path']`
3. **Usage**: Provider (`lib/puppet/provider/dsc_resource/dsc_resource.rb`) reads via `Facter.value(:dsc_install_path)`
4. **Updates**: Overwritten if `install_dir` parameter changes
5. **Deletion**: Only if user manually removes the file (not handled by module)

---

### 5. Download Artifacts (Transient)

**Purpose**: Temporary files during DSC installation process.

**Attributes**:

| Attribute | Type | Lifecycle | Description |
|-----------|------|-----------|-------------|
| `download_url` | String (URL) | Computed → Used once | GitHub release asset URL |
| `temp_archive` | String (file path) | Created → Deleted | Temporary archive file location |
| `archive_contents` | Binary data | Extracted → Discarded | DSC binary extracted from archive |

**File Locations**:
- Windows: `C:/Windows/Temp/dsc.{zip}`
- Unix: `/tmp/dsc.{tar.gz}`

**Lifecycle**:
```
download_url computed
↓
Archive downloaded to temp_archive
↓
Archive extracted to install_dir
↓
temp_archive deleted (cleanup)
```

---

## Data Flow Diagram

```
User Declaration
    ↓
[dsc class parameters: install_dir, version, manage_path]
    ↓
Fact-based Detection
    ↓
[Platform Configuration: kernel, arch, defaults computed]
    ↓
Parameter Resolution
    ↓
[actual_install_dir = pick($install_dir, $default_install_dir)]
    ↓
Download URL Construction
    ↓
[download_url = f(version, arch, platform)]
    ↓
Installation Process
    ↓
[File resources + Exec resources apply configuration]
    ↓
External Fact Creation
    ↓
[dsc_install.json written with actual_install_dir]
    ↓
Subsequent Puppet Runs
    ↓
[Facter loads dsc_install.json → exposes dsc_install_path fact]
    ↓
Provider Usage
    ↓
[dsc_resource provider reads Facter.value(:dsc_install_path)]
    ↓
DSC Invocation
    ↓
[Provider constructs full binary path: File.join(dsc_install_path, binary_name)]
```

---

## Validation Rules Summary

**At Class Declaration**:
- `install_dir` must be absolute path (enforced by `Stdlib::Absolutepath` type)
- `version` must be non-empty string
- `manage_path` must be boolean

**At Runtime**:
- `kernel` must be 'windows', 'Linux', or 'Darwin' (fail otherwise)
- `architecture` must map to 'x86_64' or 'aarch64' (fail otherwise)
- Download URL must be accessible (exec failure if not)
- Archive extraction must succeed (exec failure if not)
- Installation directory must be writable (file resource failure if not)

**Post-Installation**:
- DSC binary must exist at expected path (creates parameter ensures idempotency)
- DSC binary must be functional (proposed: `dsc --version` validation)
- External fact file must be valid JSON (fact loading handles gracefully, returns nil on parse errors)

---

## Performance Considerations

**Installation Time**:
- Download: 30-60 seconds (depends on network, file size ~50-100MB)
- Extraction: 5-10 seconds
- Fact file write: <1 second
- Total first-run: ~45-90 seconds

**Idempotency Check Time**:
- File existence checks: <1 second
- Exec `creates` parameter: <1 second (no command execution if file exists)
- Total subsequent runs: <5 seconds (no changes)

**Memory Usage**:
- Archive download: Stream to disk, minimal memory
- Archive extraction: Platform-native tools (tar, Expand-Archive)
- Fact file: <1KB in memory

---

## Notes

- The data model is intentionally simple because DSC installation is a straightforward "download, extract, configure" process
- Most "data" is configuration and computed state rather than persistent domain entities
- The external fact file is the only persistent data artifact, and it's intentionally minimal (single field JSON)
- Error states are terminal - Puppet run fails, requiring manual intervention or retry
