# Implementation Plan: DSC Resource Type Management

**Branch**: `004-dsc-resource-management` | **Date**: 2025-12-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-dsc-resource-management/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a Puppet defined type (`dsc::psmodule`) to manage PowerShell DSC module lifecycle (install, remove, upgrade) from PowerShell Gallery or custom sources. This enables administrators to declaratively manage which PowerShell modules containing DSC resources are available on target systems. The implementation uses Puppet's defined type pattern with PowerShell 7+ cmdlets via pwshlib, requires exact version specification, performs idempotent upgrades, and includes an optional structured fact for module discovery.

## Technical Context

**Language/Version**: Ruby 2.7+ (Puppet Agent 8.x requirement), Puppet DSL 6.0+, PowerShell 7.2+ (DSC v3 requirement)  
**Primary Dependencies**: Puppet Agent 8.x, puppetlabs/pwshlib (PowerShell execution), puppetlabs/stdlib (parameter validation), PowerShell 7+ with PowerShellGet module  
**Storage**: File system (PowerShell module paths under `$env:PSModulePath`), optional fact caching (file-based cache invalidated on catalog application)  
**Testing**: rspec-puppet (defined type unit tests), rspec (Ruby fact unit tests), PDK test harness, integration tests on Windows/Linux/macOS  
**Target Platform**: Cross-platform (Windows Server 2016+, Linux with PowerShell 7+, macOS with PowerShell 7+)  
**Project Type**: Puppet module extension (defined type + optional custom fact)  
**Performance Goals**: Module operations complete within 5 minutes for 50MB modules, fact collection <2 seconds with caching  
**Constraints**: Exact version specification only (no 'latest'), no automatic retries on network failure, fail-fast error handling, cache invalidation on module changes  
**Scale/Scope**: Manage 10-50 PowerShell modules per node, dependency chains up to 5 levels deep, idempotent across unlimited Puppet runs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Puppet Standards and PDK
✅ **PASS** - Using PDK for module development, following PDK directory structure (manifests/, lib/facter/), compatible with PDK 3.4.0+

### Principle II: Test-Driven Development with rspec-puppet
✅ **PASS** - Plan includes test-first development for defined type and custom fact, unit tests before implementation, integration tests for cross-platform validation

### Principle III: Documentation Standards with Puppet Strings
✅ **PASS** - Plan includes Puppet Strings annotations for defined type parameters, example usage documentation, REFERENCE.md generation

### Principle IV: Validation and Quality Gates
✅ **PASS** - All code will pass `pdk validate` with zero offenses, metadata.json includes version-pinned dependencies (pwshlib, stdlib), CI validation enforced

### Principle V: Code Quality and Idiomatic Puppet
✅ **PASS** - Using defined type (declarative), Puppet data types for parameter validation, idempotency is core requirement (FR-006), separation of concerns (defined type + optional fact)

**Overall Status**: ✅ **ALL GATES PASSED** - No violations, ready to proceed to Phase 0

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
├── init.pp                    # Existing DSC installation class
└── psmodule.pp               # NEW: Defined type for module management

lib/
├── facter/
│   ├── dsc_install_path.rb   # Existing: dscv3_info fact
│   └── dsc_modules.rb        # NEW: Optional structured fact for installed modules
└── puppet/
    ├── provider/
    │   └── dsc_resource/
    │       └── dsc_resource.rb  # Existing provider
    └── type/
        └── dsc_resource.rb      # Existing type

spec/
├── classes/
│   └── init_spec.rb          # Existing
├── defines/
│   └── psmodule_spec.rb      # NEW: Unit tests for dsc::psmodule
├── unit/
│   ├── facter/
│   │   ├── dsc_install_path_spec.rb  # Existing
│   │   └── dsc_modules_spec.rb       # NEW: Unit tests for dsc_modules fact
│   └── puppet/
│       ├── provider/
│       │   └── dsc_resource/         # Existing
│       └── type/
│           └── dsc_resource_spec.rb  # Existing
└── fixtures/
    ├── manifests/
    │   └── site.pp
    └── modules/
        ├── dsc/                      # Symlink to module root
        ├── pwshlib/                  # Existing dependency
        └── stdlib/                   # Existing dependency

examples/
├── init.pp                    # Existing
├── basic_file.pp             # Existing
└── psmodule.pp               # NEW: Example usage of dsc::psmodule

data/
└── common.yaml               # Existing Hiera data
```

**Structure Decision**: Standard Puppet module structure following PDK conventions. New functionality adds:
1. `manifests/psmodule.pp` - Defined type for module lifecycle management
2. `lib/facter/dsc_modules.rb` - Optional structured fact for discovery
3. `spec/defines/psmodule_spec.rb` - Comprehensive unit tests
4. `spec/unit/facter/dsc_modules_spec.rb` - Fact unit tests
5. `examples/psmodule.pp` - Usage examples

No changes to existing type/provider structure. Defined type uses existing infrastructure (pwshlib, Puppet resource model).

## Complexity Tracking

No violations - section not needed.

---

## Phase 0 Output: Research Complete ✅

**Research Document**: [research.md](./research.md)

**Key Decisions**:
1. Use Puppet defined type (not native resource type) for simplicity
2. PowerShellGet cmdlets for module operations with `-Scope AllUsers`
3. Idempotent upgrades by removing old version before installing new
4. Optional structured fact with cache-until-next-run strategy
5. Fail-fast error handling without automatic retries
6. Leverage existing PowerShell repository infrastructure for offline support
7. Cross-platform testing on Windows, Linux, macOS

**All unknowns resolved** - Ready for Phase 1.

---

## Phase 1 Output: Design & Contracts Complete ✅

**Data Model**: [data-model.md](./data-model.md)

**Core Entities**:
- `dsc::psmodule` defined type with parameters: ensure, version, repository, source
- `dsc_modules` structured fact with caching
- Module Installation State (internal model)
- Module Repository (external entity)
- Module Dependency (implicit, handled by PowerShell)

**Contracts**: [contracts/powershell-module-management.md](./contracts/powershell-module-management.md)

**Contract Specifications**:
- Module existence check (Get-InstalledModule)
- Module installation (Install-Module with -RequiredVersion)
- Module uninstallation (Uninstall-Module)
- Module discovery for fact (Get-InstalledModule list)
- Error handling for 7 error categories
- Idempotency contract
- Performance contract (timeouts)

**Quickstart**: [quickstart.md](./quickstart.md)

**Implementation Guide**:
- Step-by-step defined type creation
- PowerShell template examples
- Unit test scaffolding
- Optional fact implementation
- Usage examples for common scenarios
- Validation checklist

**Agent Context Updated**: ✅ Added Ruby 2.7+, Puppet DSL 6.0+, PowerShell 7.2+, pwshlib, PowerShellGet

---

## Constitution Re-Check (Post-Design)

### Principle I: Puppet Standards and PDK
✅ **PASS** - Design follows PDK structure (manifests/, lib/facter/, spec/)

### Principle II: Test-Driven Development
✅ **PASS** - Quickstart includes comprehensive unit tests before implementation

### Principle III: Documentation Standards
✅ **PASS** - Puppet Strings annotations defined in quickstart examples

### Principle IV: Validation and Quality Gates
✅ **PASS** - Validation checklist included in quickstart

### Principle V: Code Quality
✅ **PASS** - Declarative defined type, parameter validation, idempotency enforced

**Overall Status**: ✅ **ALL GATES PASSED** - Ready for Phase 2 (Tasks)

---

## Summary

**Planning Status**: ✅ **COMPLETE** (Phase 0 & Phase 1 done)

**Artifacts Created**:
1. ✅ plan.md (this file)
2. ✅ research.md - All technical decisions documented
3. ✅ data-model.md - Entities, relationships, validation rules
4. ✅ contracts/powershell-module-management.md - PowerShell interface contract
5. ✅ quickstart.md - 10-minute implementation guide
6. ✅ .github/copilot-instructions.md - Agent context updated

**Next Command**: `/speckit.tasks` to generate task breakdown

**Implementation Readiness**: ✅ **READY** - All design decisions made, contracts defined, quickstart available

---

**Branch**: `004-dsc-resource-management`  
**Spec**: [spec.md](./spec.md)  
**Plan Date**: 2025-12-16  
**Status**: Phase 1 Complete, Ready for Phase 2 (Tasks)
