# Feature Specification: DSC Class Reimplementation

**Feature Branch**: `003-dsc-class-rewrite`  
**Created**: 2025-12-16  
**Status**: Draft  
**Input**: User description: "Our dsc class to manage the installation and configuration of DSC is not functional. Lets start over with init.pp. The dsc class should manage the installation of DSC v3. The installation directory should have sensible defaults for each corresponding operating system. Users should be able to override the default install directory as desired. Our provider for dsc_resource needs to be able to leverage this install dir to be able to invoke dsc. a custom fact may be a good solution, but I am open to other solutions as long as DSC is always called even when it is not in the PATH."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Default DSC Installation (Priority: P1)

As a system administrator, I want DSC v3 to be automatically installed to a sensible default location for my operating system when I include the dsc class, so that I can start managing DSC resources immediately without manual configuration.

**Why this priority**: This is the core functionality that enables all DSC resource management. Without a working DSC installation, no other features function. This represents the minimum viable product.

**Independent Test**: Can be fully tested by including the dsc class in a manifest, applying it to a clean system, and verifying DSC is installed and functional at the expected default location. Delivers immediate value by enabling basic DSC resource management.

**Acceptance Scenarios**:

1. **Given** a Windows system without DSC installed, **When** I include the dsc class and apply the manifest, **Then** DSC v3 is installed to \`C:/Program Files/DSC\` and is executable
2. **Given** a Linux system without DSC installed, **When** I include the dsc class and apply the manifest, **Then** DSC v3 is installed to \`/opt/dsc\` and is executable
3. **Given** a macOS system without DSC installed, **When** I include the dsc class and apply the manifest, **Then** DSC v3 is installed to \`/usr/local/dsc\` and is executable
4. **Given** DSC is already installed at the default location, **When** I apply the manifest again, **Then** the system recognizes the existing installation and takes no action

---

### User Story 2 - Custom Installation Directory (Priority: P2)

As a system administrator with specific organizational requirements, I want to specify a custom installation directory for DSC v3, so that I can comply with my organization's file system standards and policies.

**Why this priority**: This enables the module to work in environments with strict directory policies or non-standard configurations. It's important for enterprise adoption but not critical for basic functionality.

**Independent Test**: Can be tested by specifying a custom install_dir parameter in the dsc class, applying the manifest, and verifying DSC is installed at the custom location. Works independently of default installation logic.

**Acceptance Scenarios**:

1. **Given** I specify \`install_dir => '/custom/path/dsc'\` in the dsc class, **When** I apply the manifest, **Then** DSC v3 is installed to \`/custom/path/dsc\` instead of the default location
2. **Given** I specify a Windows custom path like \`install_dir => 'D:/MyApps/DSC'\`, **When** I apply the manifest, **Then** DSC v3 is installed to \`D:/MyApps/DSC\`
3. **Given** the custom directory doesn't exist, **When** I apply the manifest, **Then** the directory structure is created and DSC is installed successfully
4. **Given** I change the install_dir parameter to a new location, **When** I apply the manifest, **Then** DSC is installed to the new location (existing installation may remain or be removed based on implementation)

---

### User Story 3 - Provider Integration Without PATH Dependency (Priority: P1)

As a Puppet module developer, I want the dsc_resource provider to always find and invoke DSC regardless of whether it's in the system PATH, so that DSC resources work reliably across all installation scenarios.

**Why this priority**: This is critical for reliability. If the provider can't consistently find DSC, the entire module becomes unreliable. This must work for both default and custom installations.

**Independent Test**: Can be tested by installing DSC via the dsc class (default or custom path), removing DSC from PATH if present, then using dsc_resource in a manifest and verifying it successfully invokes DSC. Delivers reliable resource management independent of PATH configuration.

**Acceptance Scenarios**:

1. **Given** DSC is installed via the dsc class with default settings and DSC is NOT in the system PATH, **When** I use a dsc_resource in my manifest, **Then** the provider successfully locates and invokes DSC to manage the resource
2. **Given** DSC is installed via the dsc class with a custom install_dir and DSC is NOT in the system PATH, **When** I use a dsc_resource in my manifest, **Then** the provider successfully locates and invokes DSC using the custom path
3. **Given** DSC is manually installed outside the dsc class management, **When** I use a dsc_resource in my manifest, **Then** the provider falls back to checking PATH or platform defaults to locate DSC
4. **Given** the dsc class has not been included and DSC is not found anywhere, **When** I use a dsc_resource in my manifest, **Then** the provider provides a clear error message indicating DSC is not installed

---

### Edge Cases

- What happens when the specified install_dir is on a read-only filesystem?
- What happens when DSC binary already exists at the target location but is a different version?
- What happens when the user lacks permissions to write to the install directory?
- How does the system handle partial installations (directory created but binary download fails)?
- What happens when the dsc class is applied multiple times with different install_dir values?
- How does the provider behave when multiple DSC installations exist on the system?
- What happens when the installation directory is deleted after DSC is installed?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dsc class MUST install DSC v3 to platform-specific default locations (Windows: \`C:/Program Files/DSC\`, Linux: \`/opt/dsc\`, macOS: \`/usr/local/dsc\`)
- **FR-002**: The dsc class MUST accept an optional \`install_dir\` parameter that overrides the default installation location
- **FR-003**: The dsc class MUST create the installation directory and any required parent directories if they don't exist
- **FR-004**: The dsc class MUST download or copy the DSC v3 binary to the installation directory
- **FR-005**: The dsc class MUST make the DSC binary executable on Unix-like systems (Linux, macOS)
- **FR-006**: The dsc class MUST be idempotent - repeated applications should not cause errors or unnecessary changes
- **FR-007**: The dsc_resource provider MUST locate the DSC installation path without requiring DSC to be in the system PATH
- **FR-008**: The dsc_resource provider MUST use the installation path configured by the dsc class when available
- **FR-009**: The dsc_resource provider MUST fall back to checking platform-specific default locations when the dsc class hasn't been used
- **FR-010**: The system MUST provide a mechanism for the provider to discover where the dsc class installed DSC (custom fact, catalog lookup, or similar)
- **FR-011**: The dsc class MUST handle upgrades gracefully when DSC is already installed
- **FR-012**: The system MUST validate that the DSC binary is functional after installation
- **FR-013**: The dsc class MUST fail with a clear error message if installation cannot be completed
- **FR-014**: The installation MUST work on Windows Server 2019+, Windows 10+, modern Linux distributions, and macOS 12+

### Key Entities

- **DSC Installation**: Represents the DSC v3 binary and its installation location on the target system. Attributes include installation directory path, binary name (dsc or dsc.exe), version, and functional status.
- **Installation Configuration**: Represents the user's desired DSC installation settings. Attributes include custom installation directory (optional), target operating system, and installation preferences.
- **Path Discovery Mechanism**: Represents the method by which the provider locates the DSC binary. Could be implemented as a custom fact, catalog parameter, or configuration file. Must reliably provide the installation path to the provider.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully manage DSC resources on a clean system by including the dsc class and using dsc_resource types in the same manifest (verified by successful application)
- **SC-002**: The dsc class successfully installs DSC v3 on Windows, Linux, and macOS with zero manual configuration required
- **SC-003**: The dsc_resource provider successfully invokes DSC in 100% of test cases regardless of whether DSC is in the system PATH
- **SC-004**: Users can specify custom installation directories and the provider correctly locates DSC in the custom location in all test scenarios
- **SC-005**: The dsc class completes installation within 5 minutes on systems with normal internet connectivity
- **SC-006**: Repeated applications of the dsc class (idempotency test) complete in under 10 seconds with no changes reported
- **SC-007**: The module works on at least 3 major operating systems (Windows, Ubuntu/Debian, RHEL/CentOS) and macOS without platform-specific user intervention

## Scope Boundaries *(mandatory)*

### In Scope

- DSC v3 installation and configuration management
- Platform-specific default installation paths
- Custom installation directory support
- Provider integration with installed DSC location
- Idempotent installation behavior
- Basic version management (install if missing, skip if present)
- Cross-platform support (Windows, Linux, macOS)

### Out of Scope

- Managing multiple simultaneous DSC versions
- Uninstallation or removal of DSC
- Automatic DSC version upgrades (will require explicit user action)
- DSC plugin or extension management
- Network proxy configuration for DSC downloads
- Air-gapped or offline installation scenarios
- Integration with package managers (apt, yum, chocolatey) - direct binary installation only

## Dependencies *(mandatory)*

### External Dependencies

- DSC v3 binary must be available for download or included in the module
- Target systems must have PowerShell 7.2+ installed (DSC v3 requirement)
- Network connectivity for downloading DSC binary (unless pre-packaged)
- File system write permissions at the installation location

### Internal Dependencies

- puppetlabs/pwshlib module for PowerShell execution
- Existing dsc_resource type and provider framework
- Puppet agent 8.x runtime

## Assumptions *(mandatory)*

- DSC v3 binary is available in a consistent, accessible location (download URL or module files)
- The module has already established that PowerShell 7.2+ is present via pwshlib
- Users running the dsc class have sufficient privileges to write to the default installation directories
- The target system has sufficient disk space for DSC installation (approximately 50-100MB)
- Once installed, the DSC installation directory will not be moved or deleted externally
- The custom fact approach (or alternative mechanism) can reliably communicate installation path from the dsc class to the provider
- Platform detection via Facter provides accurate operating system information

## Notes

This specification intentionally leaves the implementation mechanism for path discovery open (custom fact, catalog lookup, external file, etc.) to allow for technical evaluation during the planning phase. The requirement is that the provider can reliably locate DSC regardless of PATH - the specific mechanism is an implementation detail.
