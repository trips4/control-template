# Feature Specification: DSC Installation Path Detection

**Feature Branch**: `002-dsc-install-fact`  
**Created**: 2025-12-16  
**Status**: Draft  
**Input**: User description: "We need a custom fact so that our provider knows where DSC is installed based on the module installing DSC. We need to update our README.md to reflect the usage of the dsc class to manage dsc installation"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - DSC Provider Detects Installation Path (Priority: P1)

Module users include the `dsc` class to install DSC, and the `dsc_resource` provider automatically discovers where DSC was installed without requiring manual configuration.

**Why this priority**: Core functionality that enables the module to work seamlessly when DSC is installed via the `dsc` class rather than manually. Without this, the provider cannot locate DSC binaries installed by the module itself.

**Independent Test**: Can be fully tested by including `dsc` class with custom install path, then using `dsc_resource` type. Provider should automatically use the custom path without configuration, delivering automatic path detection.

**Acceptance Scenarios**:

1. **Given** the `dsc` class is included with default installation path, **When** a `dsc_resource` is declared, **Then** the provider uses the installation path from the `dsc` class
2. **Given** the `dsc` class is included with custom `install_dir` parameter, **When** a `dsc_resource` is declared, **Then** the provider uses the custom installation path
3. **Given** DSC is installed manually (not via `dsc` class), **When** a `dsc_resource` is declared, **Then** the provider falls back to platform default paths
4. **Given** the `dsc` class installs DSC on Windows, **When** a `dsc_resource` is evaluated, **Then** the provider correctly resolves the Windows installation path
5. **Given** the `dsc` class installs DSC on Linux, **When** a `dsc_resource` is evaluated, **Then** the provider correctly resolves the Linux installation path

---

### User Story 2 - Documentation Reflects Module-Managed Installation (Priority: P2)

Module users read the README and understand they should use the `dsc` class to install DSC rather than installing it manually.

**Why this priority**: Essential for user onboarding but does not affect technical functionality. Without this, users may not discover the automatic installation capability.

**Independent Test**: Can be tested by reviewing README sections that now document the `dsc` class usage. Delivers clear installation guidance without requiring code changes.

**Acceptance Scenarios**:

1. **Given** a user reads the README Setup section, **When** looking for installation instructions, **Then** they see clear guidance to use the `dsc` class
2. **Given** a user wants to customize DSC installation, **When** reviewing README examples, **Then** they find examples showing `install_dir` and other class parameters
3. **Given** a user follows README quickstart steps, **When** they copy example code, **Then** it includes both `dsc` class declaration and `dsc_resource` usage
4. **Given** a user checks Setup Requirements, **When** reviewing prerequisites, **Then** they understand manual DSC installation is no longer required

---

### Edge Cases

- What happens when DSC binary path fact is unavailable but manual installation exists at default location?
- How does the provider behave when the custom fact returns an invalid or non-existent path?
- What happens when DSC is installed via the `dsc` class but later removed manually from the filesystem?
- How does the provider handle path detection on unsupported platforms where the `dsc` class cannot install DSC?
- What happens when multiple Puppet agents with different platforms share catalog compilation?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a custom fact that exposes the DSC installation path configured by the `dsc` class
- **FR-002**: The custom fact MUST return the actual installation directory where DSC binary is located
- **FR-003**: The `dsc_resource` provider MUST check the custom fact for DSC installation path before falling back to hardcoded defaults
- **FR-004**: The custom fact MUST return `nil` or empty value when DSC is not installed via the `dsc` class
- **FR-005**: The provider MUST maintain backward compatibility with manual DSC installations at default paths
- **FR-006**: README MUST document the `dsc` class and its role in managing DSC installation
- **FR-007**: README Setup Requirements section MUST be updated to indicate DSC can be installed via the module
- **FR-008**: README MUST include examples showing `dsc` class usage with default and custom installation paths
- **FR-009**: README MUST show complete working examples that include both `dsc` class declaration and `dsc_resource` usage
- **FR-010**: The custom fact MUST work correctly on all supported platforms (Windows, Linux, macOS)

### Key Entities

- **Custom Fact (dsc_install_path)**: Exposes the DSC installation directory configured by the `dsc` class. Contains the absolute path to the directory containing the DSC binary. Returns `nil` when DSC is not managed by the module.
- **dsc Class**: Puppet class that installs and manages DSC v3. Configures installation path that the custom fact reads.
- **dsc_resource Provider**: Ruby provider that executes DSC commands. Consumes the custom fact to determine DSC binary location.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can install DSC and use `dsc_resource` types without manually specifying binary paths
- **SC-002**: Module works correctly with both module-managed DSC installations and manual installations
- **SC-003**: New users following README can successfully configure DSC resources within 5 minutes
- **SC-004**: Provider correctly resolves DSC binary path on Windows, Linux, and macOS when installed via `dsc` class
- **SC-005**: 100% of users who include `dsc` class with custom `install_dir` have the provider automatically use that custom path

## Assumptions *(include when making non-obvious assumptions)*

- The `dsc` class creates a deterministic installation path that can be reliably read by a custom fact
- Users who manually install DSC outside the module will continue using platform default paths
- The custom fact implementation will use Facter 3.x or 4.x APIs available in Puppet Agent 8.x
- Module installation directory is accessible to Facter during fact resolution
- Puppet catalog compilation occurs on the same node where DSC will be executed (no cross-node catalog sharing for this feature)

## Dependencies *(include when external systems/modules are required)*

- Puppet Agent >= 8.0.0 (for Facter version compatibility)
- `dsc` class must be declared before `dsc_resource` types in the catalog
- File system access to read DSC installation paths during fact resolution

## Scope Boundaries *(include to explicitly define what's excluded)*

### In Scope

- Custom fact to expose DSC installation path from `dsc` class
- Provider modification to consume the custom fact
- README documentation updates for `dsc` class usage
- Backward compatibility with manual DSC installations

### Out of Scope

- Modifying DSC binary paths for existing manual installations
- Auto-migration from manual to module-managed DSC installations
- Installation validation or health checking beyond path existence
- Support for multiple concurrent DSC installations on the same system
- Dynamic DSC binary path updates without Puppet agent restart
