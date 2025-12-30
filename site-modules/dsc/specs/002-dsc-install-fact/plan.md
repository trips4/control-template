# Implementation Plan: DSC Installation Path Detection

**Branch**: `002-dsc-install-fact` | **Date**: 2025-12-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-dsc-install-fact/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a custom Facter fact to expose the DSC installation path configured by the `dsc` class, enabling the `dsc_resource` provider to automatically discover DSC binary location. Update provider to consume this fact with fallback to platform defaults for backward compatibility. Update README documentation to guide users in managing DSC installation through the module rather than manual installation.

## Technical Context

**Language/Version**: Ruby 2.7+ (Puppet Agent 8.x requirement), PowerShell 7.2+ (DSC V3 requirement)  
**Primary Dependencies**: Puppet Agent 8.x, Facter 3.x/4.x, puppetlabs/pwshlib module  
**Storage**: File system (DSC binary paths)  
**Testing**: rspec-puppet for unit tests, rspec for Ruby provider/fact tests  
**Target Platform**: Cross-platform (Windows, Linux, macOS)  
**Project Type**: Puppet module (single project structure)  
**Performance Goals**: Fact resolution < 100ms, provider path lookup < 10ms  
**Constraints**: Must work with Puppet Agent 8.x, maintain backward compatibility with manual DSC installations  
**Scale/Scope**: Single module feature, 3 files modified (fact, provider, README), ~150 lines of code

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Puppet Standards and PDK Compliance
- ✅ **PASS**: Feature uses PDK structure, will run `pdk validate` before commit
- ✅ **PASS**: Custom fact follows Facter 3.x/4.x conventions
- ✅ **PASS**: Provider modification follows Puppet type/provider patterns

### II. Test-Driven Development
- ✅ **PASS**: Will write rspec tests for custom fact before implementation
- ✅ **PASS**: Will write rspec-puppet tests for provider path resolution
- ✅ **PASS**: Tests will cover all platforms (Windows, Linux, macOS)
- ✅ **PASS**: Edge cases from spec will have corresponding test cases

### III. Documentation Standards
- ✅ **PASS**: Custom fact will include Puppet Strings annotations
- ✅ **PASS**: Provider modifications will update existing documentation
- ✅ **PASS**: README updates are explicit requirement (FR-006 to FR-009)
- ✅ **PASS**: Examples will demonstrate usage patterns

### IV. Validation and Quality Gates
- ✅ **PASS**: `pdk validate` required with zero offenses before commit
- ✅ **PASS**: RuboCop for Ruby code (fact and provider)
- ✅ **PASS**: puppet-lint for any manifest changes
- ✅ **PASS**: All tests must pass before merge

### V. Code Quality and Idiomatic Puppet
- ✅ **PASS**: Custom fact is idiomatic Facter implementation
- ✅ **PASS**: Provider follows declarative patterns with proper fallbacks
- ✅ **PASS**: Idempotent: repeated fact resolution returns same value
- ✅ **PASS**: No exec resources needed - pure Ruby implementation

**Constitution Status**: ✅ ALL GATES PASS - Proceeding to Phase 0

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
lib/
├── facter/
│   └── dsc_install_path.rb          # NEW: Custom fact for DSC path
└── puppet/
    ├── provider/
    │   └── dsc_resource/
    │       └── dsc_resource.rb       # MODIFIED: Update dsc_binary_path method
    └── type/
        └── dsc_resource.rb           # NO CHANGE

manifests/
└── init.pp                           # NO CHANGE (already manages DSC install)

spec/
├── unit/
│   ├── facter/
│   │   └── dsc_install_path_spec.rb  # NEW: Fact unit tests
│   └── puppet/
│       └── provider/
│           └── dsc_resource/
│               └── dsc_resource_spec.rb  # MODIFIED: Add path resolution tests
└── fixtures/
    └── [existing test fixtures]

README.md                              # MODIFIED: Add dsc class usage docs
examples/
└── init.pp                            # MODIFIED: Show dsc class + dsc_resource
```

**Structure Decision**: Puppet module structure using PDK conventions. Custom fact in `lib/facter/`, provider modification in existing provider file, tests mirror source structure in `spec/unit/`. Documentation updates in README and examples.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A - All constitution checks passed.

---

## Phase 0: Research ✅ COMPLETE

**Output**: [research.md](./research.md)

**Key Decisions**:
1. Use external facts written to disk as communication channel (manifest → fact → provider)
2. Fact file location: `/etc/puppetlabs/facter/facts.d/dsc_install.json` (platform-specific)
3. Return `nil` when DSC not module-managed (enables fallback to defaults)
4. Early-exit optimization pattern for performance
5. Comprehensive error handling with graceful degradation

**Research Topics Covered**:
- Custom fact implementation patterns
- Fact-manifest communication (catalog timing constraints)
- DSC class parameter detection strategy
- Performance optimization (< 100ms target)
- Testing strategies with RSpec

---

## Phase 1: Design & Contracts ✅ COMPLETE

**Outputs**:
- [data-model.md](./data-model.md) - Entity definitions and data flow
- [contracts/external-fact-schema.md](./contracts/external-fact-schema.md) - JSON schema for external fact file
- [quickstart.md](./quickstart.md) - User guide with examples

**Key Artifacts**:

### Data Model
- **External Fact File**: JSON file written by manifest, read by custom fact
- **Custom Fact**: `dsc_install_path` - Ruby fact that parses external file
- **Provider Path Resolution**: Updated `dsc_binary_path` method with fallback logic
- **State Flow**: Documented two-run convergence pattern

### Contract
- JSON schema v1.0.0 for external fact file format
- Single required field: `dsc_install_path` (absolute path string)
- Platform-specific file locations
- Error handling specifications
- Validation rules and test cases

### Quickstart
- User-facing documentation with working examples
- Basic usage, custom paths, cross-platform examples
- Troubleshooting guide
- FAQ section

### Agent Context Update ✅
- Updated `.github/copilot-instructions.md` with:
  - Ruby 2.7+ (Puppet Agent 8.x requirement)
  - PowerShell 7.2+ (DSC V3 requirement)
  - Puppet Agent 8.x, Facter 3.x/4.x, puppetlabs/pwshlib module
  - File system (DSC binary paths)

---

## Constitution Re-Check (Post-Design)

### I. Puppet Standards and PDK Compliance
- ✅ **PASS**: Design follows PDK structure conventions
- ✅ **PASS**: Custom fact uses standard Facter patterns
- ✅ **PASS**: External fact file in standard location

### II. Test-Driven Development
- ✅ **PASS**: Test strategy documented in research.md
- ✅ **PASS**: Fact tests planned: `spec/unit/facter/dsc_install_path_spec.rb`
- ✅ **PASS**: Provider tests planned: update to existing spec file
- ✅ **PASS**: Coverage targets defined (100% for new code)

### III. Documentation Standards
- ✅ **PASS**: Quickstart provides user documentation
- ✅ **PASS**: Data model documents technical design
- ✅ **PASS**: Contract specifies API/interface
- ✅ **PASS**: Puppet Strings annotations planned for fact

### IV. Validation and Quality Gates
- ✅ **PASS**: Plan requires `pdk validate` before commit
- ✅ **PASS**: RuboCop planned for Ruby code
- ✅ **PASS**: All tests must pass before merge

### V. Code Quality and Idiomatic Puppet
- ✅ **PASS**: Design uses idiomatic Facter patterns
- ✅ **PASS**: External facts standard Puppet mechanism
- ✅ **PASS**: Provider fallback ensures backward compatibility
- ✅ **PASS**: No exec resources - pure Ruby/Puppet DSL

**Post-Design Status**: ✅ ALL GATES PASS - Ready for Phase 2 (Tasks)

---

## Next Steps

Run `/speckit.tasks` to generate detailed implementation tasks based on this plan.

**Phase 2 Will Create**:
- Task breakdown for implementation
- Test-first workflow steps
- Validation checkpoints
- Estimated effort per task

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
