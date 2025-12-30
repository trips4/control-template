# PowerShell Module Management Contract

**Feature**: 004-dsc-resource-management  
**Date**: 2025-12-16  
**Purpose**: Define the contract between Puppet (dsc::psmodule) and PowerShell cmdlets

## Overview

This contract specifies the PowerShell commands, expected inputs, outputs, and error conditions for module management operations. The Puppet defined type MUST conform to these interfaces when invoking PowerShell via pwshlib.

---

## 1. Module Existence Check

**Purpose**: Determine if a module is installed and its version

**PowerShell Command**:
```powershell
Get-InstalledModule -Name '<MODULE_NAME>' -ErrorAction SilentlyContinue | 
  Select-Object Name, Version, InstalledLocation, Repository | 
  ConvertTo-Json -Compress
```

**Input Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| MODULE_NAME | String | Yes | Name of the module to check |

**Success Response** (Exit Code 0):
```json
{
  "Name": "PSDesiredStateConfiguration",
  "Version": "2.0.7",
  "InstalledLocation": "C:\\Program Files\\PowerShell\\Modules\\PSDesiredStateConfiguration\\2.0.7",
  "Repository": "PSGallery"
}
```

**Not Found Response** (Exit Code 0):
```
(empty string or null)
```

**Error Response** (Exit Code != 0):
```
Get-InstalledModule: <error message>
```

**Contract Requirements**:
- MUST return JSON string if module found
- MUST return empty/null if module not found (not an error)
- MUST use `-ErrorAction SilentlyContinue` to avoid terminating errors
- Version MUST be string in SemVer format (X.Y.Z)

---

## 2. Module Installation

**Purpose**: Install a specific version of a module from a repository

**PowerShell Command** (from repository):
```powershell
Install-Module -Name '<MODULE_NAME>' `
  -RequiredVersion '<VERSION>' `
  -Repository '<REPOSITORY>' `
  -Scope AllUsers `
  -Force `
  -ErrorAction Stop
```

**PowerShell Command** (from local file):
```powershell
# Two-step process
Save-Module -Name '<MODULE_NAME>' -RequiredVersion '<VERSION>' -Path '<TEMP_DIR>' -Repository '<REPOSITORY>'
Copy-Item -Path '<TEMP_DIR>\<MODULE_NAME>' -Destination '<MODULES_PATH>' -Recurse -Force
```

**Input Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| MODULE_NAME | String | Yes | Name of the module to install |
| VERSION | String | Yes | Exact version in SemVer format (X.Y.Z) |
| REPOSITORY | String | No | Repository name (default: PSGallery) |
| SCOPE | String | Yes | Must be 'AllUsers' for system-wide installation |

**Success Response** (Exit Code 0):
```
(no output expected - silent success)
```

**Error Responses** (Exit Code != 0):

| Error Condition | Exit Code | Message Pattern |
|----------------|-----------|-----------------|
| Module not found | 1 | `No match was found for the specified search criteria` |
| Repository not registered | 1 | `Unable to find repository '<REPOSITORY>'` |
| Network failure | 1 | `Unable to connect to the remote server` |
| Permission denied | 1 | `Administrator rights are required` |
| Disk space insufficient | 1 | `There is not enough space on the disk` |
| Version not found | 1 | `No match was found for the specified search criteria and module name '<MODULE_NAME>'` |

**Contract Requirements**:
- MUST use `-RequiredVersion` (not `-MinimumVersion` or `-MaximumVersion`)
- MUST use `-Scope AllUsers` for system-wide installation
- MUST use `-Force` to skip confirmation prompts
- MUST use `-ErrorAction Stop` to ensure errors are caught
- Dependencies MUST be installed automatically (PowerShell default behavior)
- Installation MUST be idempotent (can re-run safely if already installed)

---

## 3. Module Uninstallation

**Purpose**: Remove a specific version of an installed module

**PowerShell Command**:
```powershell
Uninstall-Module -Name '<MODULE_NAME>' `
  -RequiredVersion '<VERSION>' `
  -Force `
  -ErrorAction Stop
```

**Input Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| MODULE_NAME | String | Yes | Name of the module to uninstall |
| VERSION | String | Yes | Exact version to remove (X.Y.Z) |

**Success Response** (Exit Code 0):
```
(no output expected - silent success)
```

**Error Responses** (Exit Code != 0):

| Error Condition | Exit Code | Message Pattern |
|----------------|-----------|-----------------|
| Module not found | 1 | `No match was found` |
| Permission denied | 1 | `Administrator rights are required` |
| Module in use | 1 | `The module '<MODULE_NAME>' could not be uninstalled because it is currently in use` |

**Contract Requirements**:
- MUST use `-RequiredVersion` to remove specific version only
- MUST use `-Force` to skip confirmation prompts
- MUST use `-ErrorAction Stop` to ensure errors are caught
- Uninstallation MUST NOT remove dependencies (only specified module)
- Uninstallation MUST be idempotent (can re-run safely if already removed)

---

## 4. Module Discovery (for Fact)

**Purpose**: List all installed modules for fact generation

**PowerShell Command**:
```powershell
Get-InstalledModule | 
  Select-Object Name, Version, InstalledLocation, Repository | 
  ConvertTo-Json -Depth 2
```

**Input Parameters**: None

**Success Response** (Exit Code 0):
```json
[
  {
    "Name": "PSDesiredStateConfiguration",
    "Version": "2.0.7",
    "InstalledLocation": "C:\\Program Files\\PowerShell\\Modules\\PSDesiredStateConfiguration\\2.0.7",
    "Repository": "PSGallery"
  },
  {
    "Name": "Pester",
    "Version": "5.5.0",
    "InstalledLocation": "C:\\Program Files\\PowerShell\\Modules\\Pester\\5.5.0",
    "Repository": "PSGallery"
  }
]
```

**Empty Response** (Exit Code 0, no modules installed):
```json
[]
```

**Error Response** (Exit Code != 0):
```
Get-InstalledModule: <error message>
```

**Contract Requirements**:
- MUST return JSON array (empty array if no modules)
- MUST include Name, Version, InstalledLocation, Repository fields
- Version MUST be string in SemVer format
- Response MUST be valid JSON

---

## 5. Repository Validation

**Purpose**: Verify a repository is registered before attempting installation

**PowerShell Command**:
```powershell
Get-PSRepository -Name '<REPOSITORY>' -ErrorAction Stop | ConvertTo-Json
```

**Input Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| REPOSITORY | String | Yes | Name of the repository to validate |

**Success Response** (Exit Code 0):
```json
{
  "Name": "PSGallery",
  "SourceLocation": "https://www.powershellgallery.com/api/v2",
  "Trusted": false,
  "Registered": true,
  "InstallationPolicy": "Untrusted"
}
```

**Error Response** (Exit Code != 0):
```
Get-PSRepository: Unable to find repository '<REPOSITORY>'. Use Get-PSRepository to see all available repositories.
```

**Contract Requirements**:
- MUST use `-ErrorAction Stop` to catch unregistered repositories
- Exit code != 0 indicates repository not registered
- Puppet MUST fail with clear error if repository not found

---

## 6. Module Version Validation

**Purpose**: Verify a specific module version exists in repository before installing

**PowerShell Command**:
```powershell
Find-Module -Name '<MODULE_NAME>' `
  -RequiredVersion '<VERSION>' `
  -Repository '<REPOSITORY>' `
  -ErrorAction Stop | 
  Select-Object Name, Version | 
  ConvertTo-Json
```

**Input Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| MODULE_NAME | String | Yes | Name of the module |
| VERSION | String | Yes | Exact version to find (X.Y.Z) |
| REPOSITORY | String | No | Repository to search (default: all) |

**Success Response** (Exit Code 0):
```json
{
  "Name": "PSDesiredStateConfiguration",
  "Version": "2.0.7"
}
```

**Error Response** (Exit Code != 0):
```
Find-Module: No match was found for the specified search criteria and module name '<MODULE_NAME>'.
```

**Contract Requirements**:
- MUST use `-RequiredVersion` for exact match
- Exit code != 0 indicates version not found
- Optional validation step (can skip and let Install-Module fail instead)

---

## Error Handling Contract

### Error Categories and Expected Behavior

| Error Category | PowerShell Exit Code | Puppet Behavior | User Message |
|----------------|---------------------|-----------------|--------------|
| Module not found | != 0 | Fail with Error | "Module '<name>' version '<version>' not found in repository '<repo>'" |
| Repository not registered | != 0 | Fail with Error | "Repository '<name>' is not registered. Register it using Register-PSRepository." |
| Network failure | != 0 | Fail with Error | "Unable to reach repository '<repo>'. Check network connectivity." |
| Permission denied | != 0 | Fail with Error | "Insufficient privileges. Puppet must run with administrator/root privileges." |
| Disk space | != 0 | Fail with Error | "Insufficient disk space to install module '<name>'." |
| Generic PowerShell error | != 0 | Fail with Error | "PowerShell error: <stderr output>" |

### Error Detection

**Puppet MUST**:
1. Check PowerShell exit code (0 = success, != 0 = error)
2. Capture stderr output for error messages
3. Parse stderr for known error patterns
4. Provide actionable error messages to user
5. NOT retry automatically (fail-fast per clarification)

**Example Error Handling**:
```ruby
result = Pwsh::Manager.execute(powershell_command)

if result[:exitcode] != 0
  error_message = result[:stderr]
  
  case error_message
  when /No match was found/
    raise Puppet::Error, "Module '#{module_name}' version '#{version}' not found in repository '#{repository}'"
  when /Unable to find repository/
    raise Puppet::Error, "Repository '#{repository}' is not registered. Register it using Register-PSRepository."
  when /Unable to connect/
    raise Puppet::Error, "Unable to reach repository '#{repository}'. Check network connectivity."
  when /Administrator rights are required/
    raise Puppet::Error, "Insufficient privileges. Puppet must run with administrator/root privileges."
  else
    raise Puppet::Error, "PowerShell module operation failed: #{error_message}"
  end
end
```

---

## Platform-Specific Considerations

### Windows
- PowerShell 7+ typically installed at `C:\Program Files\PowerShell\7\pwsh.exe`
- Module path: `C:\Program Files\PowerShell\Modules`
- PowerShellGet typically pre-installed
- All commands work as documented

### Linux
- PowerShell 7+ must be installed separately
- Module path: `/usr/local/share/powershell/Modules` or `/opt/microsoft/powershell/7/Modules`
- PowerShellGet may need to be installed: `pwsh -Command "Install-Module -Name PowerShellGet -Force"`
- All commands work identically to Windows

### macOS
- PowerShell 7+ must be installed separately (via Homebrew or pkg)
- Module path: `/usr/local/microsoft/powershell/7/Modules`
- PowerShellGet may need to be installed
- All commands work identically to Windows

**Contract Requirement**: Puppet implementation MUST NOT have platform-specific PowerShell command variations. All commands MUST be cross-platform compatible via PowerShell 7+.

---

## Performance Contract

### Timeouts

| Operation | Maximum Duration | Timeout Behavior |
|-----------|-----------------|------------------|
| Module existence check | 5 seconds | Fail with timeout error |
| Module installation | 5 minutes | Fail with timeout error |
| Module uninstallation | 30 seconds | Fail with timeout error |
| Module discovery | 10 seconds | Fail with timeout error |

**Puppet MUST** implement timeouts using pwshlib timeout mechanisms to prevent hung operations.

### PowerShell Invocation Overhead

- Each PowerShell invocation: ~200-500ms startup overhead
- Puppet SHOULD minimize number of PowerShell calls
- Recommended: 1-2 PowerShell calls per dsc::psmodule resource evaluation

---

## Idempotency Contract

### Install Operation

**Scenario**: Module already installed at correct version

**Expected Behavior**:
```powershell
# Check current state
$installed = Get-InstalledModule -Name 'ModuleName' -ErrorAction SilentlyContinue

if ($installed.Version -eq '1.0.0') {
    # Already at correct version - NO ACTION TAKEN
    # Puppet reports: no changes
}
```

### Uninstall Operation

**Scenario**: Module already not installed

**Expected Behavior**:
```powershell
# Check current state
$installed = Get-InstalledModule -Name 'ModuleName' -ErrorAction SilentlyContinue

if ($null -eq $installed) {
    # Already absent - NO ACTION TAKEN
    # Puppet reports: no changes
}
```

### Upgrade Operation

**Scenario**: Module installed at different version

**Expected Behavior**:
```powershell
# Check current state
$installed = Get-InstalledModule -Name 'ModuleName' -ErrorAction SilentlyContinue

if ($installed.Version -ne '2.0.0') {
    # Version mismatch - ACTION REQUIRED
    Uninstall-Module -Name 'ModuleName' -RequiredVersion $installed.Version -Force
    Install-Module -Name 'ModuleName' -RequiredVersion '2.0.0' -Force
    # Puppet reports: changed
}
```

**Contract Requirement**: Puppet MUST check current state before every operation to ensure idempotency. No action should be taken if system is already in desired state.

---

## Testing Contract

### Unit Test Requirements

Puppet unit tests MUST mock PowerShell execution and test:
1. Parameter validation (version format, mutual exclusivity)
2. State resolution logic (install/upgrade/uninstall decisions)
3. Error handling for all error categories
4. Idempotency scenarios (no action when already correct)

### Integration Test Requirements

Integration tests MUST execute real PowerShell commands and verify:
1. Actual module installation from PSGallery
2. Actual module upgrade (version change)
3. Actual module removal
4. Idempotency across multiple Puppet runs
5. Cross-platform compatibility (Windows, Linux, macOS)

**Test Module Recommendations**:
- Use small, stable module like 'Pester' (PowerShell testing framework)
- Avoid large modules that slow tests
- Clean up modules after tests

---

## Versioning and Compatibility

**PowerShell Version**: 7.2 or newer (DSC v3 requirement)
**PowerShellGet Version**: 2.0 or newer (for `-RequiredVersion` parameter)
**Puppet Version**: 8.0 or newer
**pwshlib Version**: 1.1.0 or newer

**Contract Stability**: This contract is considered stable and SHOULD NOT change without major version increment. Any breaking changes to PowerShell cmdlet interfaces MUST be handled with backward compatibility or documented migration path.

---

## Summary

This contract defines the exact PowerShell commands, parameters, responses, and error handling that the Puppet `dsc::psmodule` defined type MUST implement. Key requirements:

1. **Exact version specification** using `-RequiredVersion`
2. **System-wide installation** using `-Scope AllUsers`
3. **Fail-fast error handling** with clear messages
4. **Idempotency checks** before every operation
5. **Cross-platform compatibility** via PowerShell 7+
6. **Performance timeouts** to prevent hung operations
7. **Comprehensive testing** with mocked and real PowerShell execution

Adherence to this contract ensures reliable, predictable, and maintainable PowerShell module management through Puppet.
