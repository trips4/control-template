# Feature Specification: DSC Resource Type Management

**Feature Branch**: `004-dsc-resource-management`  
**Created**: 2025-01-10  
**Status**: Draft  
**Input**: User description: "mechanism for adding and removing dsc_resource types so that they are available on the system WHEN needed"

## Clarifications

### Session 2025-12-16

- Q: User Story 2 scope - should system detect and remove "unused" modules automatically or only remove modules explicitly declared with `ensure => absent`? → A: Only manage modules explicitly declared in Puppet manifests. System does not automatically detect or remove unused modules.
- Q: Version Pinning Strategy - How should the system handle version specifications for PowerShell modules? → A: Support exact versions only (e.g., `version => '2.0.5'`) - no 'latest' keyword
- Q: Module Update Behavior - When a module is already installed at version 2.0.0 and the user changes the Puppet manifest to specify version 3.0.0, what should happen? → A: Remove old version and install new version automatically (idempotent upgrade)
- Q: Offline/Air-Gapped Support - How should the system support enterprise environments without direct internet access to PowerShell Gallery? → A: Rely on users setting up their own PowerShell repositories using existing tools (Register-PSRepository)
- Q: Fact Performance & Caching - Should the `dsc_modules` structured fact cache its results to avoid running PowerShell on every Facter invocation? → A: Yes, cache until next Puppet run (invalidate on catalog application)
- Q: Network Failure Retry Strategy - When PowerShell Gallery is unreachable during module installation, how should the system handle retries? → A: No automatic retries - fail immediately and let Puppet's normal run cycle handle it

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Install PowerShell DSC Module (Priority: P1)

As a Puppet administrator, I need to install PowerShell Gallery modules (like PSDesiredStateConfiguration) so that legacy PowerShell DSC resources become available to the dsc_resource type.

**Why this priority**: This is the most common use case - administrators need access to the extensive library of existing PowerShell DSC resources. Without this capability, only native DSC v3 resources are available, which is a significant limitation.

**Independent Test**: Can be fully tested by declaring a `dsc::psmodule` resource with module name 'PSDesiredStateConfiguration', applying the catalog, and verifying the module is installed via `Get-InstalledModule`. Delivers immediate value by enabling legacy DSC resource usage.

**Acceptance Scenarios**:

1. **Given** DSC is installed but no PowerShell modules are present, **When** administrator declares `dsc::psmodule { 'PSDesiredStateConfiguration': ensure => present }`, **Then** the module is installed from PowerShell Gallery and available to DSC
2. **Given** PSDesiredStateConfiguration module is already installed, **When** Puppet runs again, **Then** the resource reports no changes (idempotent)
3. **Given** a module installation is requested with a specific version, **When** Puppet applies the catalog, **Then** that exact version is installed
4. **Given** a module has dependencies, **When** the module is installed, **Then** all dependencies are automatically installed

---

### User Story 2 - Remove Specified PowerShell Modules (Priority: P2)

As a system administrator, I need to remove PowerShell DSC modules that are explicitly declared with `ensure => absent` in my Puppet manifest to reduce system footprint and potential security exposure.

**Why this priority**: While installation is critical, cleanup is also important for security and maintenance. This enables proper lifecycle management of DSC resources. The system only manages modules explicitly declared in Puppet manifests.

**Independent Test**: Can be fully tested by first installing a module, then changing `ensure => absent`, applying, and verifying removal via `Get-InstalledModule`. Delivers value by enabling complete module lifecycle management.

**Acceptance Scenarios**:

1. **Given** PSDesiredStateConfiguration module is installed, **When** administrator sets `ensure => absent`, **Then** the module is uninstalled
2. **Given** a module is not installed, **When** `ensure => absent` is applied, **Then** the resource reports no changes (idempotent)
3. **Given** a module is declared with `ensure => absent`, **When** removal is attempted, **Then** the module is removed regardless of whether other (non-Puppet-managed) resources might reference it

---

### User Story 3 - Query Installed DSC Resources (Priority: P3)

As a Puppet administrator, I need to see what DSC resources are currently available on the system to understand what resources I can use in my configurations.

**Why this priority**: This is helpful for discovery and troubleshooting but not essential for basic functionality. Administrators can use PowerShell commands directly if needed.

**Independent Test**: Can be fully tested by running a query command/fact and verifying it returns accurate information about installed modules and available DSC resources. Delivers value by improving discoverability.

**Acceptance Scenarios**:

1. **Given** multiple PowerShell modules are installed, **When** administrator queries available resources, **Then** all DSC resources from all modules are listed
2. **Given** no PowerShell modules are installed, **When** administrator queries available resources, **Then** only native DSC v3 resources are listed
3. **Given** a module is newly installed, **When** administrator queries resources, **Then** the new resources appear in the list

---

### User Story 4 - Install Custom/Local DSC Modules (Priority: P3)

As a developer, I need to install DSC modules from local file paths or custom repositories (not PowerShell Gallery) to test custom resources or use internal company modules.

**Why this priority**: This is important for advanced users, enterprise scenarios, and air-gapped environments but not required for basic functionality. Most users will use PowerShell Gallery modules. This story covers offline support.

**Independent Test**: Can be fully tested by specifying a local .nupkg file or custom repository, applying the catalog, and verifying the module is installed and available. Delivers value for custom resource development, enterprise deployments, and offline environments.

**Acceptance Scenarios**:

1. **Given** a DSC module .nupkg file exists locally, **When** administrator specifies `source => '/path/to/module.nupkg'`, **Then** the module is installed from the local file
2. **Given** a custom PowerShell repository is registered, **When** administrator specifies `repository => 'CompanyRepo'`, **Then** the module is installed from that repository
3. **Given** a module directory exists on disk, **When** administrator specifies `source => '/path/to/module/dir'`, **Then** the module is copied to the PowerShell modules directory

---

### Edge Cases

- What happens when PowerShell Gallery is unreachable during module installation? → Fail immediately with network error, rely on next Puppet run to retry
- How does the system handle module installation when disk space is insufficient?
- What occurs if a module installation is interrupted (system crash, network failure)?
- How are conflicting module versions handled when different versions are requested?
- What happens when attempting to install a module that doesn't exist in PowerShell Gallery?
- How does the system behave on Linux/macOS where PowerShell Gallery access may differ?
- What occurs when a module has circular dependencies?
- How are module version changes handled when the new version has different dependencies than the old version?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Puppet defined type or resource type for managing PowerShell DSC modules
- **FR-002**: System MUST support installing modules from PowerShell Gallery by name
- **FR-003**: System MUST support installing specific module versions using exact semantic version strings (e.g., '2.0.5'). Version parameter is required - no default 'latest' behavior.
- **FR-004**: System MUST automatically install module dependencies when present
- **FR-005**: System MUST support removing installed modules
- **FR-006**: System MUST be idempotent - repeated applications with same parameters produce no changes
- **FR-007**: System MUST verify module installation success before reporting completion
- **FR-008**: System MUST handle module installation failures gracefully with clear error messages. No automatic retries—failures should be reported immediately.
- **FR-009**: System MUST work on Windows, Linux, and macOS where PowerShell 7+ is available
- **FR-010**: System MUST support installing modules from local file paths (.nupkg files)
- **FR-011**: System MUST support installing modules from custom PowerShell repositories
- **FR-012**: System MUST use PowerShell 7+ (same version used by DSC v3) for all module operations
- **FR-013**: System MUST preserve module state across Puppet runs
- **FR-014**: System SHOULD provide a structured fact listing installed PowerShell modules relevant to DSC
- **FR-014a**: The `dsc_modules` fact SHOULD cache results between Puppet runs and invalidate cache after module changes to optimize performance
- **FR-015**: System MUST validate that DSC is installed before attempting module operations
- **FR-016**: System MUST handle module updates when version parameter changes from one specific version to another by automatically removing the old version and installing the new version (idempotent upgrade)

### Key Entities

- **PowerShell Module**: A PowerShell module package that may contain DSC resources. Key attributes: name, version, repository source, installation path, dependencies
- **DSC Resource**: A configuration resource provided by a PowerShell module. Key attributes: resource name, module name, version, properties schema
- **Module Repository**: A source location for PowerShell modules. Key attributes: repository name, URL, authentication requirements. Default is PowerShell Gallery (PSGallery)
- **Module Installation State**: The desired and actual state of a module. Key attributes: module name, ensure (present/absent/version), actual_version, installation_path

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can install any PowerShell Gallery module and use its DSC resources within 2 Puppet runs (one to install module, one to use resources)
- **SC-002**: Module installation operations complete within 5 minutes for modules up to 50MB in size
- **SC-003**: 100% of module installations either succeed or fail with clear, actionable error messages
- **SC-004**: Module management operations work identically on Windows, Linux, and macOS with PowerShell 7+
- **SC-005**: Zero false "changes detected" reports on subsequent Puppet runs after module installation (perfect idempotency)
- **SC-006**: Administrators can successfully remove modules without affecting other installed modules or active DSC configurations
- **SC-007**: Module dependency chains of up to 5 levels deep are resolved and installed automatically
- **SC-008**: Module installations succeed in offline/air-gapped environments when users configure custom PowerShell repositories or use local .nupkg files

## Technical Design Considerations *(optional, for specification phase)*

### Implementation Approach

- **Primary Implementation**: Create a `dsc::psmodule` defined type that wraps PowerShell module management cmdlets
- **Alternative Considered**: Create a native `dsc_psmodule` resource type with Ruby provider
  - Trade-off: Native type provides better performance but requires more complex Ruby/PowerShell integration
  - Decision: Start with defined type for faster implementation, can migrate to native type if performance issues arise

### PowerShell Integration

- Use `Pwsh::Manager` from puppetlabs/pwshlib for PowerShell execution
- Primary cmdlets: `Install-Module`, `Uninstall-Module`, `Get-InstalledModule`, `Find-Module`
- All operations use `-Scope AllUsers` for system-wide installation
- Version handling: Always use `-RequiredVersion` parameter with exact version string (no ranges or 'latest')

### Platform Differences

- **Windows**: Full PowerShell Gallery support out of the box
- **Linux/macOS**: Requires PowerShell 7+ to be installed first (handled by `dsc` class)
- **Module Paths**: Use PowerShell's automatic path detection (`$env:PSModulePath`)

### Fact Design

- **Fact Name**: `dsc_modules` (structured fact)
- **Structure**: Array of hashes, each containing: `{ 'name' => '...', 'version' => '...', 'path' => '...' }`
- **Discovery Method**: Execute `Get-InstalledModule | ConvertTo-Json` via PowerShell
- **Caching Strategy**: Cache results until next Puppet catalog application. This avoids expensive PowerShell invocations during Facter collection while ensuring the fact reflects actual state after module changes.
- **Cache Invalidation**: Puppet provider invalidates cache after any module install/uninstall operation

### Error Handling

- Network failures during Gallery access: Fail immediately with clear error message. No automatic retries—Puppet's normal run cycle will retry on next run.
- Missing dependencies: Let PowerShell handle automatically (Install-Module has built-in dependency resolution)
- Insufficient permissions: Fail fast with clear error about requiring administrative/root privileges
- Module not found: Fail with error indicating module name may be incorrect or not available in specified repository

### Dependencies

- Requires: `dsc` class to be applied first (DSC and PowerShell 7+ installed)
- Requires: puppetlabs/pwshlib module for PowerShell execution
- Optional: puppetlabs/stdlib for parameter validation functions

## Open Questions

No outstanding questions - all clarifications resolved.

## Definition of Done

- [ ] All P1 user stories have acceptance criteria met
- [ ] Unit tests achieve 100% code coverage for new defined type
- [ ] Integration tests verify module installation/removal on Windows, Linux, and macOS
- [ ] Documentation includes examples for all user stories
- [ ] REFERENCE.md updated with API documentation for `dsc::psmodule`
- [ ] Feature works in offline environments (with local module sources)
- [ ] All edge cases have defined behavior and error handling
- [ ] Performance testing shows module operations complete within success criteria timeframes
- [ ] Idempotency verified through repeated Puppet runs showing no changes
