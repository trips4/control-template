# Feature Specification: Puppet-DSC V3 Integration Module

**Feature ID**: 1-dsc-v3-integration  
**Created**: 2025-11-10  
**Status**: Draft  
**Stakeholders**: Puppet module developers, DevOps engineers managing Windows and cross-platform infrastructure

---

## Executive Summary

### Purpose

Enable Puppet developers to manage Microsoft DSC (Desired State Configuration) V3 resources directly within Puppet manifests using familiar Puppet DSL syntax. This integration allows infrastructure teams to leverage DSC V3's cross-platform capabilities while maintaining a unified Puppet-based configuration management approach.

### Value Proposition

- **Unified Management**: Manage DSC resources alongside traditional Puppet resources in a single manifest
- **Cross-Platform Support**: Leverage DSC V3's support for Windows, Linux, and macOS through PowerShell 7.2+
- **Native Puppet Experience**: Use Puppet DSL syntax patterns familiar to Puppet developers
- **Modern DSC Integration**: Focus exclusively on DSC V3, avoiding legacy PowerShell DSC complexity
- **Reduced Toolchain Complexity**: Eliminate need for separate DSC configuration management

---

## Feature Overview

### What This Feature Does

This module provides a Puppet type (`dsc_resource`) and provider that translates Puppet resource declarations into DSC V3 command invocations. When a Puppet agent processes a manifest containing `dsc_resource` declarations, the provider:

1. Translates Puppet resource parameters into DSC V3 input format
2. Invokes the appropriate DSC V3 command on the managed node
3. Reports resource state back to Puppet for catalog application
4. Handles idempotency through DSC V3's test/get/set pattern

### What This Feature Does NOT Do

- Support PowerShell DSC (versions 1.x, 2.x) or Windows Management Framework DSC
- Provide DSC resource authoring capabilities (users must install DSC resources separately)
- Auto-discover or bundle DSC resources with the module
- Convert existing PowerShell DSC configurations to Puppet manifests
- Manage PowerShell or DSC installation (assumes prerequisites are met)

---

## User Scenarios & Testing

### Primary User Flow

**Actor**: Puppet developer managing infrastructure with DSC resources

**Scenario**: Configure a file resource using DSC V3 through Puppet

```puppet
dsc_resource { 'ensure_config_file':
  resource_type => 'Microsoft.Windows/Registry',
  module_name   => 'Microsoft.Windows',
  properties    => {
    keyPath   => 'HKLM:\Software\MyApp',
    valueName => 'ConfigPath',
    valueData => 'C:\ProgramData\MyApp\config.json',
    ensure    => 'present',
  },
}
```

**Expected Outcome**:
1. Puppet agent translates this into a DSC V3 command
2. DSC V3 checks current registry state (test operation)
3. If state differs, DSC V3 applies configuration (set operation)
4. Puppet catalog reports success/failure with detailed output

### Secondary User Flows

**Scenario 2**: Cross-platform package management using DSC V3

```puppet
dsc_resource { 'install_nginx':
  resource_type => 'DSC/Package',
  module_name   => 'DSC',
  properties    => {
    name   => 'nginx',
    ensure => 'present',
  },
}
```

**Expected Outcome**: Works identically on Windows, Linux, and macOS where DSC V3 Package resource is available.

**Scenario 3**: Dependency ordering with native Puppet resources

```puppet
package { 'powershell':
  ensure => '7.4.0',
}

dsc_resource { 'configure_app':
  resource_type => 'MyOrg/AppConfig',
  module_name   => 'MyOrg.DSC',
  properties    => { ... },
  require       => Package['powershell'],
}
```

**Expected Outcome**: Puppet's dependency graph ensures PowerShell is installed before invoking DSC.

---

## Functional Requirements

### Core Capabilities

1. **DSC Resource Declaration**
   - Support `dsc_resource` type in Puppet manifests
   - Accept parameters: `resource_type`, `module_name`, `properties`, `ensure`
   - Validate that required DSC V3 prerequisites exist on target node before application

2. **DSC V3 Command Translation**
   - Convert Puppet resource properties to DSC V3 JSON/YAML input format
   - Map Puppet's `ensure => present/absent` to DSC resource's equivalent
   - Handle nested property structures (hashes, arrays)
   - Preserve data types (strings, integers, booleans) during translation

3. **Idempotent Operations**
   - Invoke DSC V3 test operation to check current state before changes
   - Only trigger set operation when current state differs from desired state
   - Report no changes when state already matches desired configuration

4. **Error Handling & Reporting**
   - Capture DSC V3 command output (stdout, stderr, exit codes)
   - Translate DSC errors into Puppet-friendly error messages
   - Fail Puppet run if DSC resource application fails
   - Provide actionable error messages when DSC module/resource not found

5. **Cross-Platform Support**
   - Function on any OS where PowerShell 7.2+ is installed
   - Detect PowerShell availability and version during provider initialization
   - Support platform-specific DSC resource invocation patterns

6. **Puppet Integration**
   - Support standard Puppet metaparameters (`require`, `before`, `notify`, `subscribe`)
   - Enable DSC resources to trigger refreshes of dependent Puppet resources
   - Integrate with Puppet's reporting and logging infrastructure

### Acceptance Criteria

**For each requirement**:

1. **DSC Resource Declaration**
   - Given a manifest with `dsc_resource`, When puppet agent applies catalog, Then DSC V3 command is invoked with correct parameters
   - Given invalid `resource_type`, When catalog applies, Then Puppet fails with clear error message

2. **DSC V3 Command Translation**
   - Given nested properties hash, When translated, Then resulting DSC input maintains structure
   - Given `ensure => absent`, When translated, Then DSC receives appropriate removal instruction

3. **Idempotent Operations**
   - Given resource already in desired state, When catalog applied twice, Then second run reports no changes
   - Given resource in wrong state, When catalog applied, Then DSC set operation executes

4. **Error Handling & Reporting**
   - Given DSC module not installed, When catalog applies, Then error message includes module name and installation guidance
   - Given DSC resource fails, When catalog applies, Then Puppet run fails with DSC's error details

5. **Cross-Platform Support**
   - Given Linux node with PowerShell 7.2+, When catalog with DSC resource applied, Then resource configures successfully
   - Given node without PowerShell, When catalog applies, Then provider fails preflight check with helpful message

6. **Puppet Integration**
   - Given `dsc_resource` with `require => Package['foo']`, When catalog applies, Then DSC resource waits for package installation
   - Given `dsc_resource` with `notify => Service['bar']`, When DSC resource changes, Then service receives refresh signal

---

## Success Criteria

### Measurable Outcomes

1. **Functional Success**
   - Puppet developers can declare DSC V3 resources using native Puppet syntax without learning DSC CLI
   - 100% of DSC V3 resource types are addressable through the module (no resource type filtering/restrictions)
   - DSC resource state changes integrate seamlessly with Puppet's dependency graph

2. **Reliability**
   - Idempotent behavior: Running the same manifest twice with unchanged desired state results in 0 changes on second run
   - Error rate < 1% for valid DSC resource configurations (excluding user errors like typos)

3. **Performance**
   - DSC resource invocation overhead < 2 seconds per resource (excluding actual DSC operation time)
   - Module supports catalogs with 50+ DSC resources without Puppet agent timeout

4. **Compatibility**
   - Module operates on all platforms supported by PowerShell 7.2+ (Windows, Ubuntu, RHEL, macOS, etc.)
   - Supports Puppet Agent 8.0.0 through 8.x

5. **Developer Experience**
   - Puppet developers require < 10 minutes to understand basic `dsc_resource` usage from documentation
   - Error messages provide clear remediation steps (e.g., "Install DSC module 'Microsoft.Windows' with: Install-PSResource...")

---

## Key Entities

### DSC Resource Metadata

**Attributes**:
- Resource Type (string): Fully qualified DSC resource name (e.g., `Microsoft.Windows/Registry`)
- Module Name (string): DSC module containing the resource
- Properties (hash): DSC resource property values
- Ensure State (enum: present/absent): Desired existence state

**Relationships**:
- Belongs to a DSC Module (installed on target node)
- May depend on other Puppet resources (packages, files, services)

### DSC Module

**Attributes**:
- Module Name (string): PowerShell module name
- Version (string): Semantic version
- Installation Source (string): PSGallery or custom repository

**Relationships**:
- Contains one or more DSC Resources
- Required prerequisite for `dsc_resource` usage

### Puppet Manifest

**Attributes**:
- File Path (string): Location of .pp manifest file
- Resources (array): Collection of Puppet and DSC resources

**Relationships**:
- Contains zero or more `dsc_resource` declarations
- Applied by Puppet Agent during catalog application

---

## User Experience

### Typical Workflow

1. **Setup Phase** (one-time per node):
   - Install PowerShell 7.2+ on managed nodes
   - Install required DSC modules via `Install-PSResource`
   - Install this Puppet module via Puppetfile or `puppet module install`

2. **Development Phase**:
   - Author Puppet manifests including `dsc_resource` declarations
   - Test manifests in development environment
   - Validate DSC module availability on target nodes

3. **Deployment Phase**:
   - Deploy manifests via Puppet infrastructure (Puppet Server, r10k, etc.)
   - Puppet agents apply catalogs containing DSC resources
   - Review Puppet reports for DSC resource state changes

### Key User Interactions

- **Resource Declaration**: Puppet developer writes `dsc_resource` in manifest using standard Puppet syntax
- **Catalog Application**: Puppet agent automatically translates and invokes DSC without user intervention
- **Error Resolution**: User reads Puppet error messages, installs missing DSC modules or fixes property values
- **State Verification**: User runs Puppet in noop mode to preview DSC changes before application

---

## Scope & Boundaries

### In Scope

- Puppet type and provider for invoking DSC V3 resources
- Translation logic from Puppet DSL to DSC V3 input format
- Cross-platform support (any OS with PowerShell 7.2+)
- Integration with Puppet's dependency ordering and notification system
- Error handling and reporting for DSC operations
- Documentation for Puppet developers

### Out of Scope

- PowerShell DSC (versions < 3.0) support
- DSC resource authoring or bundling
- Automatic DSC module installation or discovery
- PowerShell installation management
- DSC configuration document generation
- Conversion tools from existing DSC configurations
- GUI or web-based DSC resource management

### Dependencies

**External**:
- PowerShell 7.2 or newer installed on managed nodes
- DSC V3 available via PowerShell modules
- Target DSC modules installed on nodes (e.g., `Microsoft.Windows`, custom modules)

**Internal**:
- Puppet Agent 8.0.0 or newer
- Standard Puppet module dependencies (stdlib if needed for validation)

### Constraints

- **Platform**: Limited to operating systems supported by PowerShell 7.2+
- **DSC Version**: Only DSC V3 is supported; legacy DSC not compatible
- **Performance**: DSC resource execution time dependent on underlying DSC implementation
- **Prerequisites**: Users must manually install PowerShell and DSC modules

---

## Assumptions

1. **PowerShell Availability**: Target nodes have PowerShell 7.2+ installed and available in PATH
2. **DSC Module Management**: Users manage DSC module installation separately (via PSGallery, internal repositories, or configuration management)
3. **DSC V3 Stability**: DSC V3 command-line interface and JSON/YAML input format remain stable across minor versions
4. **Puppet Expertise**: Users have intermediate Puppet knowledge (understand resources, dependencies, providers)
5. **Cross-Platform Parity**: DSC V3 resources behave consistently across supported platforms (Windows, Linux, macOS)
6. **Network Access**: Nodes have network access to DSC module repositories during initial setup phase
7. **Permissions**: Puppet agent runs with sufficient privileges to invoke DSC operations (typically root/Administrator)

---

## Design Decisions

### DSC Schema Validation Strategy

**Decision**: The module will rely on DSC V3 for all parameter validation (no pre-validation in Puppet provider).

**Rationale**: 
- Aligns with Puppet's traditional provider model where external tools handle their own validation
- Reduces module complexity and maintenance burden
- Avoids schema synchronization issues between Puppet provider and DSC modules
- Faster Puppet catalog compilation (no schema introspection overhead)
- Users receive standard DSC error messages they're already familiar with
- Errors surface during catalog application with full DSC diagnostic context

**Trade-offs Accepted**:
- Parameter errors detected during catalog application rather than catalog compilation
- Users must wait for DSC execution to discover validation errors
- No early feedback during manifest authoring (though Puppet's noop mode can be used for validation)

---

## Notes

- This specification intentionally excludes PowerShell DSC (versions 1.x/2.x) to reduce complexity and focus on modern, cross-platform DSC V3
- The module name `dsc_resource` follows Puppet's convention of singular resource type names
- DSC V3 uses JSON or YAML for input; provider must choose appropriate format based on DSC version detection
- Future enhancements may include DSC resource discovery/enumeration features, but this is deferred to maintain focused initial scope
- Integration testing requires multi-platform CI (Windows, Linux, macOS) with PowerShell 7.2+ installed

---

**Version**: 1.0.0  
**Last Updated**: 2025-11-10
