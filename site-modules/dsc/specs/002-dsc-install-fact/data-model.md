# Data Model: DSC Installation Path Detection

**Feature**: 002-dsc-install-fact  
**Date**: 2025-12-16  
**Purpose**: Define data structures and state for DSC installation path management

---

## Overview

This feature involves three primary entities that coordinate to expose and consume DSC installation paths. There is no database or persistent storage beyond the external fact file on the file system.

---

## Entity 1: External Fact File

**Purpose**: Persistent storage for DSC installation path written by the `dsc` class during catalog application.

**Location**:
- **Windows**: `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json`
- **Linux/macOS**: `/etc/puppetlabs/facter/facts.d/dsc_install.json`

**Format**: JSON

**Schema**:
```json
{
  "dsc_install_path": "/absolute/path/to/dsc"
}
```

**Fields**:

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `dsc_install_path` | String | Yes | Absolute path to directory containing DSC binary | Must be absolute path, directory must exist |

**Lifecycle**:
- **Created**: During first Puppet run when `dsc` class is included
- **Updated**: When `dsc` class `install_dir` parameter changes
- **Deleted**: When `dsc` class is removed from catalog (out of scope for this feature)
- **Read**: Every Puppet run during fact resolution

**Permissions**:
- **Owner**: root (Linux/macOS), SYSTEM (Windows)
- **Mode**: 644 (readable by all, writable by owner)

**Size**: < 100 bytes (single JSON object)

---

## Entity 2: Custom Fact (dsc_install_path)

**Purpose**: Facter fact that exposes DSC installation path to Puppet manifests and providers.

**Type**: Ruby custom fact (not external fact, though it reads external fact file)

**Location**: `lib/facter/dsc_install_path.rb`

**Resolution Logic**:
1. Check if external fact file exists at platform-specific location
2. If exists: Parse JSON and extract `dsc_install_path` value
3. If not exists or parse fails: Return `nil`

**Return Values**:

| Value | Meaning | Provider Behavior |
|-------|---------|-------------------|
| String (absolute path) | DSC installed via `dsc` class at this path | Use this path + binary name |
| `nil` | DSC not managed by module or fact not yet written | Fall back to platform defaults |

**Platform Specifics**:

| Platform | Fact File Path | Expected Return Value Example |
|----------|----------------|-------------------------------|
| Windows | `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json` | `C:/Program Files/DSC` |
| Linux | `/etc/puppetlabs/facter/facts.d/dsc_install.json` | `/opt/dsc` |
| macOS | `/etc/puppetlabs/facter/facts.d/dsc_install.json` | `/usr/local/dsc` |

**Error Handling**:

| Error Condition | Return Value | Logged Message |
|-----------------|--------------|----------------|
| File not found | `nil` | Debug: "DSC install fact file not found" |
| JSON parse error | `nil` | Debug: "Failed to parse DSC install fact: [error]" |
| Permission denied | `nil` | Warning: "Cannot read DSC install fact (permissions)" |
| Missing key | `nil` | Debug: "DSC install fact missing required key" |

---

## Entity 3: Provider Binary Path Resolution

**Purpose**: Logic within `dsc_resource` provider to determine full path to DSC binary.

**Location**: `lib/puppet/provider/dsc_resource/dsc_resource.rb` - method `dsc_binary_path`

**Resolution Algorithm**:

```ruby
def dsc_binary_path
  # Step 1: Try custom fact
  custom_path = Facter.value(:dsc_install_path)
  
  # Step 2: If fact available, construct full binary path
  if custom_path && !custom_path.empty?
    binary_name = Facter.value(:kernel) == 'windows' ? 'dsc.exe' : 'dsc'
    return File.join(custom_path, binary_name)
  end
  
  # Step 3: Fall back to platform defaults
  case Facter.value(:kernel)
  when 'windows'
    'C:\\Windows\\DSC\\dsc.exe'
  else
    '/opt/DSC/dsc'
  end
end
```

**State Transitions**:

```
[Provider initialized]
        ↓
[Check Facter.value(:dsc_install_path)]
        ↓
    ┌───────┴───────┐
    ↓               ↓
[Fact = String] [Fact = nil]
    ↓               ↓
[Use custom]   [Use default]
    ↓               ↓
[Construct      [Return platform
 full path]      default path]
    ↓               ↓
    └───────┬───────┘
            ↓
    [Execute DSC]
```

**Return Values**:

| Scenario | Platform | Return Value |
|----------|----------|--------------|
| Custom fact available | Windows | `{custom_path}\dsc.exe` |
| Custom fact available | Linux | `{custom_path}/dsc` |
| Custom fact available | macOS | `{custom_path}/dsc` |
| Fact nil/missing | Windows | `C:\Windows\DSC\dsc.exe` |
| Fact nil/missing | Linux | `/opt/DSC/dsc` |
| Fact nil/missing | macOS | `/opt/DSC/dsc` |

---

## Data Flow

### Scenario 1: First Puppet Run (DSC Class Included)

```
[Puppet Run 1 Starts]
        ↓
[Facter collects facts]
        ↓
[dsc_install_path = nil] (fact file doesn't exist yet)
        ↓
[Catalog compiled with facts]
        ↓
[dsc class applied]
        ↓
[Manifest writes: /etc/.../dsc_install.json]
        ↓
[DSC binary installed]
        ↓
[Puppet Run 1 Complete]

[Puppet Run 2 Starts]
        ↓
[Facter collects facts]
        ↓
[dsc_install_path reads file] → Returns path
        ↓
[Catalog compiled with facts]
        ↓
[dsc_resource provider uses custom path]
        ↓
[DSC operations succeed]
```

### Scenario 2: Subsequent Runs (Fact Already Written)

```
[Puppet Run N Starts]
        ↓
[Facter collects facts]
        ↓
[dsc_install_path reads file] → Returns cached path
        ↓
[Catalog compiled with facts]
        ↓
[dsc_resource provider uses custom path]
        ↓
[DSC operations succeed]
```

### Scenario 3: Manual DSC Installation (No Module Management)

```
[Puppet Run Starts]
        ↓
[Facter collects facts]
        ↓
[dsc_install_path = nil] (no fact file, dsc class not used)
        ↓
[Catalog compiled with facts]
        ↓
[dsc_resource provider falls back to defaults]
        ↓
[DSC operations succeed if manually installed at default path]
```

---

## Validation Rules

### External Fact File Validation

**Format Validation**:
- ✅ Must be valid JSON
- ✅ Must contain root object (not array)
- ✅ Must contain `dsc_install_path` key
- ✅ Value must be string (not null, number, or object)

**Content Validation**:
- ✅ Path must be absolute (start with `/` on Unix, drive letter on Windows)
- ⚠️ Path should exist on filesystem (soft validation - warn if missing)
- ⚠️ Path should contain DSC binary (soft validation - provider handles error)

**Example Valid**:
```json
{
  "dsc_install_path": "/usr/local/dsc"
}
```

**Example Invalid**:
```json
{
  "dsc_path": "/usr/local/dsc"  // ❌ Wrong key name
}
```

```json
{
  "dsc_install_path": null  // ❌ Null value
}
```

```json
{
  "dsc_install_path": "relative/path"  // ❌ Relative path
}
```

### Custom Fact Return Validation

**Valid Returns**:
- String with absolute path: `"/opt/dsc"`
- `nil`: No fact file or error reading

**Invalid Returns** (should not occur with proper implementation):
- Empty string: `""` (should be `nil`)
- Relative path: `"./dsc"` (should validate in fact)
- Number or boolean (type error)

### Provider Path Validation

**Pre-execution Validation** (in provider):
```ruby
def dsc_binary_available?
  path = dsc_binary_path
  File.exist?(path) && File.executable?(path)
end
```

**Validation Points**:
1. Path must exist on filesystem
2. Binary must be executable
3. If validation fails, raise clear error message to user

---

## State Management

### Fact Resolution Caching

**Facter Behavior**:
- Facts resolved once per Puppet run
- Cached in memory for duration of run
- No custom caching needed in fact implementation

**Performance**:
- File read: ~5ms
- JSON parse: ~3ms
- Total: ~8-10ms per Puppet run

### Manifest State Persistence

**Write Behavior** (in `dsc` class):
```puppet
file { "${fact_dir}/dsc_install.json":
  ensure  => file,
  content => to_json_pretty({
    'dsc_install_path' => $actual_install_dir,
  }),
}
```

**Idempotency**:
- File written on every Puppet run
- Content only changes if `install_dir` parameter changes
- Puppet handles change detection (no action if content unchanged)

---

## Platform-Specific Considerations

### Windows

**Fact File Path**: `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json`
- ProgramData is hidden system folder
- Requires admin privileges to write
- Uses forward slashes in Puppet (converted by OS)

**DSC Binary Name**: `dsc.exe`

**Path Format**: Windows style with drive letter
- Example: `C:/Program Files/DSC`
- Backslashes converted to forward slashes by Puppet

### Linux

**Fact File Path**: `/etc/puppetlabs/facter/facts.d/dsc_install.json`
- Standard location for Puppet external facts
- Requires root to write
- Mode 644 for readability

**DSC Binary Name**: `dsc`

**Path Format**: UNIX absolute path
- Example: `/opt/dsc`
- Must start with `/`

### macOS

**Fact File Path**: `/etc/puppetlabs/facter/facts.d/dsc_install.json` (same as Linux)

**DSC Binary Name**: `dsc`

**Path Format**: UNIX absolute path
- Example: `/usr/local/dsc`
- Must start with `/`

---

## Summary

**Data Entities**: 3 (External fact file, Custom fact, Provider path resolution)  
**Persistent Storage**: 1 JSON file per node  
**State Management**: File-based with Facter caching  
**Validation**: Format validation in fact, content validation in provider  
**Platform Coverage**: Windows, Linux, macOS  

**Key Relationships**:
1. `dsc` class (manifest) → writes → External fact file
2. Custom fact → reads → External fact file
3. Provider → queries → Custom fact
4. Provider → falls back to → Platform defaults

This data model ensures clean separation of concerns while maintaining backward compatibility with manual DSC installations.
