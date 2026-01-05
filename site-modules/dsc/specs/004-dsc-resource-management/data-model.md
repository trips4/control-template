# Data Model: DSC Resource Type Management

**Feature**: 004-dsc-resource-management  
**Date**: 2025-12-16  
**Status**: Complete

## Overview

This document defines the data structures, entities, and their relationships for PowerShell module management in the puppetlabs-dsc module.

## Core Entities

### 1. dsc::psmodule (Defined Type)

**Purpose**: Declarative interface for managing PowerShell module lifecycle

**Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `namevar` | `String[1]` | Yes | Resource title | PowerShell module name (e.g., 'PSDesiredStateConfiguration') |
| `ensure` | `Enum['present', 'absent']` | No | `'present'` | Desired state of the module |
| `version` | `String[1]` matching `/^\d+\.\d+\.\d+$/` | Yes | None | Exact semantic version (e.g., '2.0.7'). Required - no 'latest'. |
| `repository` | `Optional[String[1]]` | No | `undef` | PowerShell repository name (default: PSGallery if unspecified) |
| `source` | `Optional[Stdlib::Absolutepath]` | No | `undef` | Local .nupkg file path for offline installation |

**Validation Rules**:
- `version` MUST match semantic versioning pattern (major.minor.patch)
- `repository` and `source` are mutually exclusive (cannot both be specified)
- If `source` is specified, file MUST exist and have `.nupkg` extension
- Module name MUST be valid PowerShell module name (alphanumeric, underscores, hyphens)

**State Transitions**:

```
                    ensure => present
   [Not Installed] ─────────────────────> [Installed v1.0.0]
                                                  │
                                                  │ ensure => absent
                                                  v
                                          [Not Installed]
                                                  ^
                                                  │ ensure => present
                    version changed               │
   [Installed v1.0.0] ──────────────────> [Uninstall v1.0.0]
         │                                        │
         │                                        v
         │                                 [Install v2.0.0]
         └────────────────────────────────> [Installed v2.0.0]
              (version unchanged,
               no action - idempotent)
```

**Example Declarations**:

```puppet
# Basic installation from PowerShell Gallery
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
}

# Installation from custom repository
dsc::psmodule { 'CompanyDSCResources':
  ensure     => present,
  version    => '3.1.0',
  repository => 'CompanyInternal',
}

# Installation from local file
dsc::psmodule { 'OfflineModule':
  ensure  => present,
  version => '1.0.0',
  source  => '/mnt/packages/OfflineModule.1.0.0.nupkg',
}

# Removal
dsc::psmodule { 'UnwantedModule':
  ensure  => absent,
  version => '1.5.2',  # Version required for deterministic removal
}
```

---

### 2. dsc_modules Fact (Structured Fact)

**Purpose**: Discover installed PowerShell modules for Puppet catalog compilation and reporting

**Fact Name**: `dsc_modules`

**Structure**: Array of hashes representing installed modules

**Schema**:
```ruby
[
  {
    'name'    => String,      # Module name (e.g., 'PSDesiredStateConfiguration')
    'version' => String,      # Installed version (e.g., '2.0.7')
    'path'    => String,      # Installation path (e.g., 'C:/Program Files/PowerShell/Modules/...')
    'repository' => String,   # Source repository (e.g., 'PSGallery')
  },
  ...
]
```

**Example Output**:
```json
[
  {
    "name": "PSDesiredStateConfiguration",
    "version": "2.0.7",
    "path": "C:/Program Files/PowerShell/Modules/PSDesiredStateConfiguration/2.0.7",
    "repository": "PSGallery"
  },
  {
    "name": "Pester",
    "version": "5.5.0",
    "path": "C:/Program Files/PowerShell/Modules/Pester/5.5.0",
    "repository": "PSGallery"
  }
]
```

**Confinement**: Only available when `dscv3_info` fact exists (DSC installed)

**Caching Strategy**:
- **Cache Location**: Platform-specific
  - Windows: `C:/ProgramData/PuppetLabs/facter/cache/dsc_modules.json`
  - Linux/macOS: `/var/cache/facter/dsc_modules.json`
- **Cache TTL**: Until next Puppet catalog application (invalidated by defined type)
- **Invalidation Trigger**: Any `dsc::psmodule` resource execution touches/deletes cache file

**Discovery Method**:
```powershell
Get-InstalledModule | Select-Object Name, Version, InstalledLocation, Repository | ConvertTo-Json
```

---

### 3. Module Installation State (Internal Model)

**Purpose**: Track the actual vs. desired state during catalog application

**Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `module_name` | String | PowerShell module name |
| `desired_ensure` | 'present' \| 'absent' | From Puppet manifest |
| `desired_version` | String (SemVer) | From Puppet manifest |
| `actual_version` | String \| nil | Currently installed version (nil if not installed) |
| `actual_path` | String \| nil | Installation path if installed |
| `needs_action` | Boolean | True if state change required |
| `action_type` | 'install' \| 'uninstall' \| 'upgrade' \| 'none' | Required action |

**State Resolution Logic**:
```ruby
def resolve_action(desired_ensure, desired_version, actual_version)
  case desired_ensure
  when 'present'
    if actual_version.nil?
      { needs_action: true, action_type: 'install' }
    elsif actual_version != desired_version
      { needs_action: true, action_type: 'upgrade' }
    else
      { needs_action: false, action_type: 'none' }
    end
  when 'absent'
    if actual_version.nil?
      { needs_action: false, action_type: 'none' }
    else
      { needs_action: true, action_type: 'uninstall' }
    end
  end
end
```

---

### 4. Module Repository (External Entity)

**Purpose**: Source location for PowerShell modules

**Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | String | Repository name (e.g., 'PSGallery', 'CompanyInternal') |
| `source_location` | URL | Repository endpoint (e.g., 'https://www.powershellgallery.com/api/v2') |
| `publish_location` | URL | Publish endpoint (if applicable) |
| `trusted` | Boolean | Whether repository is trusted |
| `registered` | Boolean | Whether repository is registered on system |

**Default Repository**:
```json
{
  "name": "PSGallery",
  "source_location": "https://www.powershellgallery.com/api/v2",
  "trusted": false,
  "registered": true
}
```

**Custom Repository Registration** (user prerequisite):
```powershell
Register-PSRepository -Name 'CompanyInternal' `
  -SourceLocation 'https://packages.company.internal/powershell' `
  -InstallationPolicy Trusted
```

**Note**: Repository management is outside scope of this feature. Users must register custom repositories via PowerShell before using them in Puppet manifests.

---

### 5. Module Dependency (Implicit Entity)

**Purpose**: PowerShell modules may depend on other modules

**Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `module_name` | String | Name of dependency module |
| `minimum_version` | String (SemVer) | Minimum required version |
| `maximum_version` | String (SemVer) \| nil | Maximum compatible version |

**Handling**: Dependencies are resolved automatically by PowerShell's `Install-Module` cmdlet. Puppet does not need to explicitly model or manage dependencies.

**Example**:
```
Module: PSDesiredStateConfiguration v2.0.7
Dependencies:
  - PSDscResources >= 2.12.0
  - PackageManagement >= 1.4.7
```

When installing PSDesiredStateConfiguration, PowerShell automatically installs missing dependencies.

---

## Relationships

```
┌─────────────────────┐
│  dsc::psmodule      │ (Puppet Defined Type)
│  (Declaration)      │
└──────────┬──────────┘
           │ declares desired state for
           │
           v
┌─────────────────────┐
│ Module Installation │ (Internal State Model)
│ State               │
└──────────┬──────────┘
           │ queries & modifies
           │
           v
┌─────────────────────┐
│  PowerShell Module  │ (File System Entity)
│  on Disk            │
└──────────┬──────────┘
           │ installed from
           │
           v
┌─────────────────────┐
│  Module Repository  │ (External Entity)
│  (PSGallery, etc.)  │
└─────────────────────┘

           ┌─────────────────────┐
           │  dsc_modules Fact   │ (Facter Structured Fact)
           └──────────┬──────────┘
                      │ discovers & caches
                      │
                      v
           ┌─────────────────────┐
           │  PowerShell Module  │ (File System Entity)
           │  on Disk            │
           └─────────────────────┘
```

**Key Relationships**:
1. **Declared → Actual**: `dsc::psmodule` defines desired state, implementation ensures actual state matches
2. **Query → Cache**: `dsc_modules` fact queries module state and caches results
3. **Module → Repository**: Modules are fetched from repositories (PSGallery or custom)
4. **Module → Dependencies**: Modules may depend on other modules (resolved by PowerShell)

---

## Data Flow

### Installation Flow

```
1. Puppet Manifest
   ↓
   dsc::psmodule { 'ModuleName': ensure => present, version => '1.0.0' }
   ↓
2. Parameter Validation
   ↓
   - Validate version format
   - Check repository XOR source
   - Validate file existence if source specified
   ↓
3. Query Current State
   ↓
   PowerShell: Get-InstalledModule -Name 'ModuleName'
   ↓
4. Determine Action
   ↓
   Compare actual_version with desired_version
   ↓
5. Execute Action (if needed)
   ↓
   Case upgrade:
     PowerShell: Uninstall-Module -Name 'ModuleName' -RequiredVersion <old>
     PowerShell: Install-Module -Name 'ModuleName' -RequiredVersion '1.0.0'
   Case install:
     PowerShell: Install-Module -Name 'ModuleName' -RequiredVersion '1.0.0'
   Case none:
     Skip (idempotent)
   ↓
6. Invalidate Fact Cache
   ↓
   Delete or touch /var/cache/facter/dsc_modules.json
   ↓
7. Report Result
   ↓
   Puppet: changed/unchanged based on action taken
```

### Fact Collection Flow

```
1. Facter Execution
   ↓
2. Check dscv3_info Confinement
   ↓
   If DSC not installed: Skip fact
   ↓
3. Check Cache Validity
   ↓
   If cache exists AND cache age < TTL AND not invalidated:
     Load from cache → Return cached data
   ↓
4. Execute Discovery (if cache invalid)
   ↓
   PowerShell: Get-InstalledModule | ConvertTo-Json
   ↓
5. Parse & Structure
   ↓
   Convert JSON to array of hashes with schema
   ↓
6. Write Cache
   ↓
   Save JSON to cache file with current timestamp
   ↓
7. Return Structured Data
   ↓
   Facter fact available to Puppet manifests
```

---

## Validation Rules Summary

| Rule | Enforcement Point | Validation Logic |
|------|-------------------|------------------|
| Version format | Puppet parameter validation | Regex: `/^\d+\.\d+\.\d+$/` |
| Mutually exclusive params | Puppet parameter validation | `(repository && source) => fail` |
| Source file existence | Puppet parameter validation | `File.exist?(source)` |
| DSC prerequisite | Defined type logic | Check `dscv3_info` fact |
| Repository registered | PowerShell execution | `Get-PSRepository` check (fail if not found) |
| Module existence | PowerShell execution | `Find-Module` before install |
| Sufficient permissions | PowerShell execution | Fail if `-Scope AllUsers` requires elevation |

---

## Error States

| Error Condition | Detection Method | Error Message | Recovery Action |
|----------------|------------------|---------------|-----------------|
| Version mismatch | Puppet validation | "Version must be in format X.Y.Z" | User corrects manifest |
| Both repo & source | Puppet validation | "Cannot specify both repository and source" | User corrects manifest |
| Source file missing | Puppet validation | "Source file '<path>' does not exist" | User provides valid path |
| DSC not installed | Fact check | "DSC must be installed before managing modules" | Apply `dsc` class first |
| Repository not found | PowerShell error | "Repository '<name>' not registered" | User registers repository |
| Module not found | PowerShell error | "Module '<name>' not found in '<repo>'" | User corrects module name |
| Network failure | PowerShell error | "Unable to reach repository '<url>'" | User checks network/waits for next run |
| Permission denied | PowerShell error | "Insufficient privileges for AllUsers scope" | User runs Puppet with admin/root |
| Disk space | PowerShell error | "Insufficient disk space" | User frees disk space |

---

## Performance Considerations

**Expensive Operations**:
1. PowerShell invocation (200-500ms overhead per call)
2. Network requests to PowerShell Gallery (1-30 seconds depending on module size)
3. Module extraction and installation (varies by module size)

**Optimization Strategies**:
1. **Single-command checks**: Combine existence + version check in one PowerShell call
2. **Fact caching**: Avoid repeated PowerShell calls during Facter collection
3. **Batch validation**: Validate all parameters in Puppet before any PowerShell execution
4. **Fail-fast**: Exit early if prerequisites not met (e.g., DSC not installed)

**Performance Targets**:
- Fact collection: < 2 seconds (with caching), < 5 seconds (cold)
- Module installation: < 5 minutes for 50MB modules
- Idempotency check: < 1 second (single PowerShell call)

---

## Summary

The data model centers on the `dsc::psmodule` defined type as the user-facing interface, with an optional `dsc_modules` fact for discovery. Internal state resolution logic determines required actions (install/upgrade/uninstall), and PowerShell cmdlets perform actual operations. The model emphasizes:

1. **Explicit version specification** for reproducibility
2. **Idempotent state management** with upgrade support
3. **Minimal PowerShell invocations** for performance
4. **Clear error messages** for troubleshooting
5. **Cross-platform compatibility** via PowerShell 7+ abstraction

All entities and relationships are fully specified. Ready for contract generation (Phase 1 continuation).
