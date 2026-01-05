# Research: DSC Resource Type Management

**Feature**: 004-dsc-resource-management  
**Date**: 2025-12-16  
**Status**: Complete

## Overview

This document consolidates research findings for implementing PowerShell module management in the puppetlabs-dsc module. All technical clarifications have been resolved through the specification process.

## Research Areas

### 1. Puppet Defined Type Best Practices

**Decision**: Use Puppet defined type (`dsc::psmodule`) rather than native resource type

**Rationale**:
- Defined types are simpler to implement and maintain (pure Puppet DSL)
- Sufficient for wrapping PowerShell cmdlets with validation logic
- Can be migrated to native type later if performance requires
- Follows puppetlabs/docker and puppetlabs/registry patterns for similar use cases

**Alternatives Considered**:
- **Native Resource Type with Ruby Provider**: Rejected for initial implementation due to increased complexity. Would provide better performance and native Puppet resource semantics but requires more Ruby code and testing overhead.
- **Exec Resource Wrappers**: Rejected as non-idiomatic. Exec resources should be avoided when declarative alternatives exist.

**Implementation Pattern**:
```puppet
# manifests/psmodule.pp
define dsc::psmodule (
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $version,  # Required - no 'latest'
  Optional[String[1]] $repository = undef,
  Optional[Stdlib::Absolutepath] $source = undef,
) {
  # Validation, PowerShell execution via pwshlib
}
```

### 2. PowerShell Module Management via PowerShellGet

**Decision**: Use Install-Module/Uninstall-Module cmdlets with `-Scope AllUsers`

**Rationale**:
- PowerShellGet is the standard module management solution for PowerShell
- Built-in dependency resolution (handles FR-004 automatically)
- Cross-platform support (Windows, Linux, macOS with PowerShell 7+)
- `-Scope AllUsers` ensures system-wide installation (not user-specific)
- `-RequiredVersion` parameter enforces exact version specification

**Key Cmdlets**:
- `Install-Module -Name <name> -RequiredVersion <version> -Scope AllUsers -Force`
- `Uninstall-Module -Name <name> -RequiredVersion <version> -Force`
- `Get-InstalledModule -Name <name>` (for idempotency checks)
- `Find-Module -Name <name> -RequiredVersion <version>` (for validation before install)

**Platform Differences**:
- Windows: PowerShellGet typically pre-installed with PowerShell 5.1+
- Linux/macOS: May need to run `Install-Module -Name PowerShellGet -Force` if not present
- All platforms use same cmdlets and behavior with PowerShell 7+

**Alternatives Considered**:
- **Save-Module + Copy-Item**: Considered for offline scenarios but rejected as primary approach. Users can set up custom repositories instead.
- **Manual .nupkg extraction**: Too low-level, loses dependency resolution benefits.

### 3. Idempotency Strategy for Module Upgrades

**Decision**: Check installed version, remove if different, install new version

**Rationale**:
- PowerShell supports side-by-side versions, but this creates ambiguity for DSC resource resolution
- Removing old version ensures deterministic behavior
- Matches Puppet's idempotent resource model (declared state = actual state)
- Prevents module clutter over time

**Implementation Logic**:
```ruby
# Pseudocode for defined type logic
current_version = pwsh('Get-InstalledModule -Name <name> | Select -ExpandProperty Version')

if ensure == 'present':
  if current_version != desired_version:
    if current_version exists:
      pwsh('Uninstall-Module -Name <name> -RequiredVersion <current_version>')
    pwsh('Install-Module -Name <name> -RequiredVersion <desired_version>')
  # else: already at correct version, no changes

if ensure == 'absent':
  if current_version exists:
    pwsh('Uninstall-Module -Name <name> -RequiredVersion <current_version>')
  # else: already absent, no changes
```

**Alternatives Considered**:
- **Allow side-by-side versions**: Rejected due to DSC resource resolution ambiguity
- **Fail on version mismatch**: Rejected as not idempotent (requires manual intervention)

### 4. Custom Fact Implementation with Caching

**Decision**: Structured fact `dsc_modules` with cache-until-next-run strategy

**Rationale**:
- Facter facts are collected frequently (every Puppet run, plus tool invocations)
- PowerShell invocation is expensive (200-500ms startup overhead)
- Module state only changes when Puppet applies catalog with module changes
- Cache invalidation strategy: timestamp-based check against last catalog application

**Implementation Approach**:
```ruby
# lib/facter/dsc_modules.rb
Facter.add(:dsc_modules) do
  confine { Facter.value(:dscv3_info) && Facter.value(:dscv3_info)['install_path'] }
  
  setcode do
    cache_file = '/var/cache/puppet/dsc_modules.json' # Platform-specific path
    cache_ttl = 3600  # 1 hour, but invalidated by catalog application
    
    if cache_valid?(cache_file, cache_ttl)
      JSON.parse(File.read(cache_file))
    else
      result = execute_pwsh('Get-InstalledModule | ConvertTo-Json')
      modules = JSON.parse(result)
      File.write(cache_file, modules.to_json)
      modules
    end
  end
end
```

**Cache Invalidation**:
- Defined type execution should touch cache file or delete it
- Alternative: Check catalog application timestamp vs. cache timestamp

**Alternatives Considered**:
- **No caching**: Rejected due to performance impact on frequent Facter calls
- **Long TTL (24 hours)**: Rejected as modules could be stale between Puppet runs
- **Manual invalidation only**: Selected approach (invalidate on module operations)

### 5. Error Handling and Network Resilience

**Decision**: Fail-fast with clear error messages, no automatic retries

**Rationale**:
- Puppet's normal run cycle provides built-in retry mechanism (30-minute default)
- Automatic retries within a single run increase complexity and unpredictability
- Clear error messages enable administrators to diagnose root cause
- Network issues are typically transient or systemic (retry won't help in latter case)

**Error Categories**:
1. **Network failures**: Fail immediately with "Unable to reach PowerShell Gallery" message
2. **Module not found**: Fail with "Module '<name>' not found in repository '<repo>'"
3. **Permission errors**: Fail with "Insufficient privileges - requires admin/root"
4. **Disk space**: Let PowerShell's natural error propagate
5. **Dependency conflicts**: Let PowerShell's dependency resolver handle or fail with clear message

**PowerShell Error Detection**:
```ruby
result = Pwsh::Manager.execute(command)
if result[:exitcode] != 0
  raise Puppet::Error, "PowerShell module operation failed: #{result[:stderr]}"
end
```

**Alternatives Considered**:
- **Exponential backoff retries**: Rejected per clarification (fail-fast preferred)
- **Background job with timeout**: Rejected as overly complex for typical use cases

### 6. Offline/Air-Gapped Environment Support

**Decision**: Rely on existing PowerShell repository infrastructure (Register-PSRepository)

**Rationale**:
- PowerShell already provides robust repository management
- Enterprises typically have internal package repositories (Artifactory, Nexus, etc.)
- `Register-PSRepository` cmdlet enables custom repository configuration
- Local .nupkg file support via `source` parameter for one-off installations

**User Workflow for Offline Environments**:
1. Administrator registers internal repository: `Register-PSRepository -Name 'CompanyRepo' -SourceLocation 'https://packages.company.internal/powershell'`
2. Puppet manifest specifies repository: `dsc::psmodule { 'CustomModule': version => '1.0.0', repository => 'CompanyRepo' }`
3. Module installs from internal source

**Local File Support**:
```puppet
dsc::psmodule { 'OfflineModule':
  ensure  => present,
  version => '1.0.0',
  source  => '/mnt/packages/OfflineModule.1.0.0.nupkg',
}
```

**Implementation**: Use `Install-Module -Name <name> -RequiredVersion <version> -Repository <repo>` when repository specified

**Alternatives Considered**:
- **Built-in cache/mirror**: Rejected as duplicating functionality
- **Puppet file resources**: Possible but loses dependency resolution benefits

### 7. Cross-Platform Testing Strategy

**Decision**: Test matrix covering Windows, Linux, and macOS with GitHub Actions

**Test Scenarios**:
1. **Unit Tests** (rspec-puppet): Mock PowerShell execution, test parameter validation, catalog compilation
2. **Integration Tests**: Real PowerShell execution on each platform
   - Windows: Windows Server 2019/2022 runners
   - Linux: Ubuntu 22.04 with PowerShell 7.2+ installed
   - macOS: macOS 12+ with PowerShell 7.2+ installed

**Key Test Cases**:
- Install module from PowerShell Gallery (PSGallery)
- Install specific version
- Upgrade from one version to another
- Remove installed module
- Handle missing module error
- Handle network failure error
- Verify idempotency (no changes on second run)
- Test with module having dependencies
- Test with custom repository
- Test with local .nupkg file

**Test Fixtures**:
- Use small, stable modules like 'Pester' (testing framework) for real installations
- Mock expensive operations in unit tests
- Use `puppetlabs_spec_helper` for rspec-puppet scaffolding

### 8. Documentation Requirements

**Decision**: Comprehensive examples in REFERENCE.md and examples/ directory

**Documentation Deliverables**:
1. **REFERENCE.md**: Auto-generated from Puppet Strings annotations
   - Parameter descriptions with types and defaults
   - Usage examples for each parameter combination
   - Common scenarios (install, upgrade, remove, offline)

2. **examples/psmodule.pp**: Complete working examples
   ```puppet
   # Basic install from PowerShell Gallery
   dsc::psmodule { 'PSDesiredStateConfiguration':
     ensure  => present,
     version => '2.0.7',
   }

   # Install from custom repository
   dsc::psmodule { 'CompanyDSCResources':
     ensure     => present,
     version    => '3.1.0',
     repository => 'CompanyRepo',
   }

   # Install from local file
   dsc::psmodule { 'OfflineModule':
     ensure  => present,
     version => '1.0.0',
     source  => '/mnt/packages/OfflineModule.1.0.0.nupkg',
   }

   # Remove module
   dsc::psmodule { 'UnwantedModule':
     ensure  => absent,
     version => '1.0.0',
   }
   ```

3. **README.md section**: High-level overview linking to REFERENCE.md

### 9. Dependency Management

**Decision**: Declare dependencies in metadata.json with version constraints

**Dependencies**:
```json
{
  "dependencies": [
    {
      "name": "puppetlabs/stdlib",
      "version_requirement": ">= 6.0.0 < 10.0.0"
    },
    {
      "name": "puppetlabs/pwshlib",
      "version_requirement": ">= 1.1.0 < 2.0.0"
    }
  ],
  "requirements": [
    {
      "name": "puppet",
      "version_requirement": ">= 8.0.0 < 9.0.0"
    }
  ]
}
```

**Rationale**:
- stdlib: Provides Stdlib::Absolutepath type for source parameter validation
- pwshlib: Provides Pwsh::Manager for PowerShell execution
- Puppet 8.x: Required for modern type system and dsc class compatibility

### 10. Performance Optimization

**Decision**: Minimize PowerShell invocations, cache where appropriate

**Optimization Strategies**:
1. **Fact caching**: Avoid repeated PowerShell calls during Facter collection
2. **Batch operations**: Check existence before attempting install/uninstall
3. **Fail-fast validation**: Validate parameters in Puppet before invoking PowerShell
4. **Single-command approach**: Use compound PowerShell commands where possible

**Example Optimized Check**:
```powershell
# Single command to check if module needs action
$module = Get-InstalledModule -Name 'MyModule' -ErrorAction SilentlyContinue
if ($null -eq $module) { exit 1 }  # Not installed
if ($module.Version -ne '2.0.0') { exit 2 }  # Wrong version
exit 0  # Correct version installed
```

**Performance Targets** (from Success Criteria):
- Module operations: < 5 minutes for 50MB modules
- Fact collection: < 2 seconds with caching
- No performance degradation with 50 modules installed

## Summary

All technical unknowns have been resolved through specification clarification and research. The implementation approach is clear:

1. **Puppet defined type** for declarative module management
2. **PowerShellGet cmdlets** for actual module operations
3. **Exact version specification** for reproducibility
4. **Idempotent upgrades** by removing old version before installing new
5. **Optional structured fact** with caching for discovery
6. **Fail-fast error handling** without automatic retries
7. **Cross-platform testing** on Windows, Linux, macOS
8. **Standard Puppet module structure** following PDK conventions

No outstanding research items. Ready to proceed to Phase 1 (Design & Contracts).
