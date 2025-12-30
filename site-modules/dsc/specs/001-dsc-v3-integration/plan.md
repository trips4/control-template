# Implementation Plan: Puppet-DSC V3 Integration Module

**Branch**: `001-dsc-v3-integration` | **Date**: 2025-11-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-dsc-v3-integration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create a Puppet module providing a `dsc_resource` type and provider that translates Puppet DSL resource declarations into DSC V3 `dsc config set` command invocations. The provider leverages the puppetlabs/pwshlib module to execute DSC commands within PowerShell 7.2+ sessions, enabling cross-platform DSC resource management through Puppet's declarative syntax. Each `dsc_resource` declaration maps to a single `dsc config set` execution, with JSON output parsed to report success, corrective changes, or failures back to Puppet.

## Technical Context

**Language/Version**: Ruby 2.7+ (Puppet Agent 8.x requirement), PowerShell 7.2+ (DSC V3 requirement)  
**Primary Dependencies**: 
- puppetlabs/pwshlib (>= 1.0.0) - PowerShell execution from Puppet
- Puppet Agent >= 8.0.0, < 9.0.0
- DSC V3 (provided by PowerShell modules on managed nodes)

**Storage**: N/A (stateless provider, DSC manages state)  
**Testing**: 
- rspec-puppet for Puppet type/provider unit tests
- rspec for Ruby unit tests
- PDK test harness for integration testing
- Multi-platform acceptance tests (Windows, Linux, macOS)

**Target Platform**: Cross-platform (any OS supporting PowerShell 7.2+: Windows, Ubuntu, RHEL, macOS, etc.)  
**Project Type**: Puppet module (PDK structure)  
**Performance Goals**: 
- DSC invocation overhead < 2 seconds per resource
- Support 50+ DSC resources per catalog without agent timeout
- Catalog compilation time increase < 100ms per dsc_resource

**Constraints**: 
- PowerShell 7.2+ must be installed on managed nodes (not managed by this module)
- DSC modules must be pre-installed on nodes
- DSC binary must be installed at standard locations:
  - Windows: `C:\Windows\DSC\dsc.exe`
  - Linux/macOS/Other: `/opt/DSC/dsc`
  - (Configurable paths planned for future release)
- Each dsc_resource = 1 `dsc config set` invocation (no batching)
- JSON parsing required for DSC output
- YAML generation required for DSC input

**Scale/Scope**: 
- Single Puppet module (puppetlabs-dsc)
- One custom type (dsc_resource)
- One provider (dsc)
- Support all DSC V3 resource types (no filtering/restrictions)
- Target: enterprise-scale catalogs (1000+ nodes, 50+ DSC resources per node)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: PDK Compliance ✅ PASS
- **Requirement**: Use PDK for module scaffolding, testing, and validation
- **Status**: This is a Puppet module, will use PDK 3.4.0+ for all operations
- **Action**: Initialize module with `pdk new module puppetlabs-dsc`

### Principle II: Test-Driven Development ✅ PASS
- **Requirement**: Tests MUST be written before implementation (Red-Green-Refactor)
- **Status**: Plan includes comprehensive rspec-puppet test suite before provider implementation
- **Action**: Write type/provider specs, verify failures, then implement

### Principle III: Puppet Strings Documentation ✅ PASS
- **Requirement**: All types and providers MUST include Puppet Strings annotations
- **Status**: Plan includes documentation for dsc_resource type with parameter descriptions and examples
- **Action**: Add @param, @example tags to type/provider Ruby code

### Principle IV: Validation and Quality Gates ✅ PASS
- **Requirement**: Zero offenses from `pdk validate`, RuboCop, puppet-lint
- **Status**: Plan includes validation steps in development workflow
- **Action**: Run `pdk validate` after each code change, fix all offenses before commit

### Principle V: Idiomatic Puppet Code ✅ PASS
- **Requirement**: Declarative resource management, data type validation, idempotency
- **Status**: dsc_resource follows Puppet type/provider pattern with idempotent operations
- **Action**: Implement test/set pattern via DSC, use Puppet data types for validation

### Dependencies Compliance ✅ PASS
- **Requirement**: All dependencies explicitly declared and version-pinned in metadata.json
- **Status**: Plan includes metadata.json with pinned dependency on puppetlabs/pwshlib
- **Action**: Declare `puppetlabs/pwshlib` with version constraints in metadata.json

**GATE STATUS**: ✅ ALL CHECKS PASSED - Proceed to Phase 0

---

## Phase 0: Research Complete ✅

**Output**: `research.md`

**Key Decisions**:
1. **DSC CLI Interface**: Use `dsc config set` with YAML input via stdin, JSON output parsing
2. **pwshlib Integration**: Persistent PowerShell sessions via `Pwsh::Manager.instance()`
3. **Type/Provider Architecture**: Ensurable type with three parameters (type, input, adapter)
4. **Idempotency**: Implement via `dsc config test` (exists?) and `dsc config set` (create)
5. **Error Handling**: Parse `hadErrors` field, fail fast with actionable messages
6. **YAML Generation**: Ruby stdlib YAML library for Puppet hash to DSC document translation
7. **Cross-Platform Testing**: Unit tests (mocked), acceptance tests (CI multi-platform matrix)
8. **Noop Mode**: DSC `--what-if` flag for Puppet noop mode

All technical unknowns resolved. Ready for Phase 1.

---

## Phase 1: Design Complete ✅

**Outputs**: 
- `data-model.md` - Entity definitions and validation rules
- `contracts/dsc-v3-cli.md` - DSC CLI interface contract
- `quickstart.md` - User-facing documentation
- `.github/copilot-instructions.md` - Agent context updated

**Key Artifacts**:
1. **Data Model**: Puppet dsc_resource entity, DSC configuration document, DSC result object
2. **Type Mappings**: Puppet to DSC type conversions, change reporting patterns
3. **Validation Rules**: Parameter validation for type, input, adapter fields
4. **CLI Contract**: Command syntax, input/output formats, error scenarios, exit codes
5. **Quickstart Guide**: Installation, basic usage, troubleshooting, best practices

---

## Constitution Re-Check (Post-Design)

*Required after Phase 1 design completion*

### Principle I: PDK Compliance ✅ MAINTAINED
- **Status**: Project structure defined using PDK conventions
- **Evidence**: Source tree uses `lib/puppet/type/` and `lib/puppet/provider/` structure
- **Next**: Initialize module with `pdk new module` in Phase 2

### Principle II: Test-Driven Development ✅ MAINTAINED
- **Status**: Test structure defined in project layout
- **Evidence**: `spec/unit/` and `spec/acceptance/` directories planned
- **Next**: Write failing tests before implementing type/provider in Phase 2

### Principle III: Puppet Strings Documentation ✅ MAINTAINED
- **Status**: Documentation requirements captured in quickstart and data model
- **Evidence**: Plan includes `@param` and `@example` annotations for type definition
- **Next**: Add Puppet Strings annotations during implementation in Phase 2

### Principle IV: Validation and Quality Gates ✅ MAINTAINED
- **Status**: Validation workflow included in development process
- **Evidence**: Parameter validation rules defined in data model
- **Next**: Run `pdk validate` as part of Phase 2 implementation

### Principle V: Idiomatic Puppet Code ✅ MAINTAINED
- **Status**: Design follows Puppet type/provider patterns
- **Evidence**: Ensurable type, parameter validation, idempotent operations via DSC test/set
- **Next**: Implement using Puppet idioms in Phase 2

### Dependencies Compliance ✅ MAINTAINED
- **Status**: Dependencies identified and will be version-pinned
- **Evidence**: pwshlib dependency documented in Technical Context
- **Next**: Declare `puppetlabs/pwshlib >= 1.0.0, < 2.0.0` in metadata.json

**RE-CHECK STATUS**: ✅ ALL PRINCIPLES MAINTAINED THROUGH DESIGN PHASE

---

**Phase 1 Complete**: All design artifacts created. Ready for `/speckit.tasks` to generate implementation tasks.

## Project Structure

### Documentation (this feature)

```text
specs/001-dsc-v3-integration/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── dsc-v3-cli.md   # DSC V3 CLI interface contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
puppetlabs-dsc/
├── lib/
│   └── puppet/
│       ├── type/
│       │   └── dsc_resource.rb          # Custom Puppet type definition
│       └── provider/
│           └── dsc_resource/
│               └── dsc.rb                # Provider implementation using pwshlib
├── spec/
│   ├── unit/
│   │   └── puppet/
│   │       ├── type/
│   │       │   └── dsc_resource_spec.rb      # Type unit tests
│   │       └── provider/
│   │           └── dsc_resource/
│   │               └── dsc_spec.rb           # Provider unit tests
│   ├── acceptance/
│   │   ├── windows_spec.rb              # Windows-specific acceptance tests
│   │   ├── linux_spec.rb                # Linux-specific acceptance tests
│   │   └── macos_spec.rb                # macOS-specific acceptance tests
│   └── fixtures/
│       └── dsc_output/                  # Sample DSC JSON outputs for testing
├── examples/
│   ├── registry.pp                      # Example: Windows Registry configuration
│   ├── package.pp                       # Example: Cross-platform package management
│   └── composite.pp                     # Example: Multiple DSC resources with dependencies
├── metadata.json                        # Module metadata with dependencies
├── REFERENCE.md                         # Generated by Puppet Strings
├── README.md                            # User-facing documentation
└── CHANGELOG.md                         # Version history
```

**Structure Decision**: Standard Puppet module structure following PDK conventions. Single module project with:
- Custom type in `lib/puppet/type/`
- Provider in `lib/puppet/provider/`
- Unit tests in `spec/unit/` mirroring source structure
- Acceptance tests in `spec/acceptance/` organized by platform
- Examples in `examples/` demonstrating common use cases

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**Status**: No violations identified. All constitution checks passed. No complexity justifications required.
