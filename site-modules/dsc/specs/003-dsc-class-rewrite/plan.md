# Implementation Plan: DSC Class Reimplementation

**Branch**: `003-dsc-class-rewrite` | **Date**: 2025-12-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-dsc-class-rewrite/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Reimplement the DSC class (`manifests/init.pp`) to reliably install DSC v3 with platform-specific defaults while allowing custom installation directories. Ensure the dsc_resource provider can locate and invoke DSC without PATH dependencies via a custom Facter fact that exposes the installation path. The implementation must be idempotent, cross-platform (Windows/Linux/macOS), and follow strict test-first development.

## Technical Context

**Language/Version**: Ruby 2.7+ (Puppet Agent 8.x requirement), PowerShell 7.2+ (DSC V3 requirement)  
**Primary Dependencies**: Puppet Agent 8.x, Facter 3.x/4.x, puppetlabs/pwshlib module  
**Storage**: File system (DSC binary paths), External facts (JSON format)  
**Testing**: rspec-puppet for Puppet manifests, rspec for Ruby code (custom facts, providers)  
**Target Platform**: Windows Server 2019+/Windows 10+, Linux (Ubuntu/Debian/RHEL/CentOS), macOS 12+
**Project Type**: Puppet module (standard PDK structure)  
**Performance Goals**: Installation <5 minutes, idempotency checks <10 seconds  
**Constraints**: Must work without DSC in PATH, zero-configuration defaults, cross-platform compatibility  
**Scale/Scope**: Single Puppet module, 3 platforms, ~200-300 LOC Puppet manifests, ~50-100 LOC Ruby provider updates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. PDK Standards Compliance
- [x] **PASS**: Module uses PDK 3.4.0+ structure and conventions
- [x] **PASS**: Will use PDK commands for validation and testing
- [x] **PASS**: Follows PDK directory structure (manifests/, lib/, spec/)

### II. Test-First Discipline (rspec-puppet)
- [x] **PASS**: Test-first development planned for all changes
- [x] **PASS**: rspec-puppet tests required for dsc class manifest updates
- [x] **PASS**: rspec tests required for custom fact and provider changes
- [x] **PASS**: Integration tests planned for cross-component behavior

### III. Puppet Strings Documentation
- [x] **PASS**: All class parameters will have Puppet Strings annotations
- [x] **PASS**: Custom fact will include Puppet Strings documentation
- [x] **PASS**: Provider updates will maintain existing documentation

### IV. Quality Gates (Zero Tolerance)
- [x] **PASS**: `pdk validate` must pass with zero offenses before commit
- [x] **PASS**: All tests must pass before code review
- [x] **PASS**: Dependencies explicitly declared in metadata.json

### V. Idiomatic Puppet Code
- [x] **PASS**: Declarative resource management approach
- [x] **PASS**: Puppet data types for parameter validation
- [x] **PASS**: Idempotent design (repeated runs produce identical results)
- [x] **PASS**: Hiera-compatible for data separation

**Constitution Status**: ✅ ALL GATES PASSED - Proceed with implementation

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
manifests/
└── init.pp                              # DSC class - installation logic (MODIFY)

lib/
├── facter/
│   └── dsc_install_path.rb             # Custom fact exposing install path (EXISTS - may need fixes)
└── puppet/
    ├── provider/
    │   └── dsc_resource/
    │       └── dsc_resource.rb         # Provider using custom fact (EXISTS - verify integration)
    └── type/
        └── dsc_resource.rb             # Type definition (EXISTS - no changes)

spec/
├── classes/
│   └── init_spec.rb                    # rspec-puppet tests for dsc class (MODIFY/CREATE)
├── unit/
│   ├── facter/
│   │   └── dsc_install_path_spec.rb   # Unit tests for custom fact (EXISTS - may need updates)
│   └── puppet/
│       ├── provider/
│       │   └── dsc_resource/
│       │       └── dsc_resource_spec.rb  # Provider tests (EXISTS - verify coverage)
│       └── type/
│           └── dsc_resource_spec.rb   # Type tests (EXISTS - no changes expected)
└── fixtures/
    └── dsc_responses/                  # Test fixtures for DSC responses (EXISTS)

examples/
├── init.pp                             # Basic usage examples (UPDATE)
└── dsc_with_custom_path.pp            # Custom path example (EXISTS)
```

**Structure Decision**: Standard Puppet module layout following PDK conventions. The existing structure is sound - we're refining the implementation logic in `manifests/init.pp`, ensuring the custom fact (`lib/facter/dsc_install_path.rb`) works correctly, and verifying provider integration. All changes follow the established module patterns from feature 002-dsc-install-fact.

## Complexity Tracking

N/A - All constitution gates passed. No violations to track or justify.

---

## Phase 0: Research (COMPLETE)

**Objective**: Resolve all technical unknowns and determine implementation approach.

**Deliverables**:
- ✅ [research.md](./research.md) - Comprehensive research covering:
  - DSC v3 installation methods (GitHub releases approach validated)
  - Custom fact implementation patterns (external facts pattern confirmed)
  - Idempotency and error handling strategies
  - Cross-platform PATH management
  - Custom installation directory handling
  - Platform detection and defaults validation
  - Upgrade and version management approach
  - Error messaging improvements needed

**Key Decisions**:
1. Keep external facts pattern from feature 002 (proven reliable)
2. Add DSC binary validation step after installation
3. Improve error messages at failure points
4. No forced upgrades - install-if-missing pattern sufficient
5. Existing architecture is sound - focus on refinement

**Status**: All NEEDS CLARIFICATION items resolved. Ready for Phase 1.

---

## Phase 1: Design & Contracts (COMPLETE)

**Objective**: Define data structures, contracts, and user-facing documentation.

**Deliverables**:
- ✅ [data-model.md](./data-model.md) - Complete data model covering:
  - DSC class parameters (install_dir, version, manage_path)
  - Platform configuration (derived state from facts)
  - Installation state transitions
  - External fact file structure
  - Download artifacts lifecycle
  - Data flow diagrams
  - Validation rules

- ✅ [contracts/external-fact-schema.md](./contracts/external-fact-schema.md) - External fact file contract:
  - JSON schema definition
  - Field specifications and validation
  - Writer/reader/consumer responsibilities
  - Lifecycle management
  - Testing requirements
  - Version 1.0.0 specification

- ✅ [quickstart.md](./quickstart.md) - User-facing guide:
  - Prerequisites and basic usage
  - Custom installation examples
  - Platform-specific examples
  - Complete working examples
  - Troubleshooting guide
  - FAQ section

- ✅ Agent context updated:
  - GitHub Copilot instructions file updated with:
    - Ruby 2.7+ (Puppet Agent 8.x requirement)
    - PowerShell 7.2+ (DSC V3 requirement)
    - Puppet Agent 8.x, Facter 3.x/4.x, pwshlib module
    - File system and external facts storage
    - Puppet module project type

**Constitution Re-Check**: ✅ All gates still passing after design phase.

**Status**: Design complete. Ready for Phase 2 (tasks breakdown).

---

## Next Steps

This plan is now complete through Phase 1. The next step is to run `/speckit.implement` which will:

1. Read this plan and the specification
2. Generate [tasks.md](./tasks.md) with detailed implementation tasks
3. Begin test-first implementation following the constitution

**Readiness Checklist**:
- ✅ Specification complete and validated
- ✅ Technical context defined
- ✅ Constitution gates passed
- ✅ Research complete (all unknowns resolved)
- ✅ Data model documented
- ✅ Contracts defined
- ✅ User documentation written
- ✅ Agent context updated
- ⏳ Implementation tasks (next phase)

**Branch**: `003-dsc-class-rewrite`  
**Command**: Ready for `/speckit.implement` to generate tasks and begin implementation
