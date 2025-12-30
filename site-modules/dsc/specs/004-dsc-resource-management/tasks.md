# Tasks: DSC Resource Type Management

**Feature**: 004-dsc-resource-management  
**Input**: Design documents from `/specs/004-dsc-resource-management/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Following TDD approach per constitution - tests written before implementation

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is a Puppet module following PDK structure:
- **Defined types**: `manifests/`
- **Facts**: `lib/facter/`
- **Unit tests**: `spec/defines/`, `spec/unit/facter/`
- **Examples**: `examples/`
- **Templates**: `templates/` (EPP templates for PowerShell)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and template structure

- [X] T001 Create PowerShell template directory `templates/`
- [X] T002 Create examples directory entry `examples/psmodule.pp`
- [X] T003 [P] Verify PDK module structure is ready for new files

**Checkpoint**: Directory structure ready for implementation ✅

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core PowerShell template infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create PowerShell check template `templates/psmodule_check.ps1.epp` for idempotency checking
- [X] T005 Create PowerShell management template `templates/psmodule_manage.ps1.epp` for install/uninstall operations
- [X] T006 Add helper functions to management template for cache invalidation

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel ✅

---

## Phase 3: User Story 1 - Install PowerShell DSC Module (Priority: P1) 🎯 MVP

**Goal**: Enable administrators to install PowerShell Gallery modules with exact versions, achieving idempotent installation that makes legacy DSC resources available

**Independent Test**: Declare `dsc::psmodule { 'PSDesiredStateConfiguration': ensure => present, version => '2.0.7' }`, apply catalog, verify module installed via `Get-InstalledModule`

### Tests for User Story 1 (TDD - Write First) ✅

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T007 [P] [US1] Create unit test file `spec/defines/psmodule_spec.rb` with test scaffolding
- [X] T008 [P] [US1] Add test case: module installation with ensure => present in `spec/defines/psmodule_spec.rb`
- [X] T009 [P] [US1] Add test case: idempotency when module already installed in `spec/defines/psmodule_spec.rb`
- [X] T010 [P] [US1] Add test case: version parameter validation (must be X.Y.Z format) in `spec/defines/psmodule_spec.rb`
- [X] T011 [P] [US1] Add test case: DSC prerequisite check (fails if dscv3_info fact missing) in `spec/defines/psmodule_spec.rb`
- [X] T012 [P] [US1] Add test case: module installation with dependencies in `spec/defines/psmodule_spec.rb`

### Implementation for User Story 1

- [X] T013 [US1] Create defined type `manifests/psmodule.pp` with parameters: ensure, version, repository, source
- [X] T014 [US1] Add Puppet Strings documentation to `manifests/psmodule.pp` for all parameters and examples
- [X] T015 [US1] Implement parameter validation in `manifests/psmodule.pp`: version format, mutual exclusivity of repository/source
- [X] T016 [US1] Implement DSC prerequisite check in `manifests/psmodule.pp` using dscv3_info fact
- [X] T017 [US1] Implement exec resource for module installation in `manifests/psmodule.pp` using pwsh provider
- [X] T018 [US1] Configure exec resource 'unless' parameter to check current state via `psmodule_check.ps1.epp` template
- [X] T019 [US1] Configure exec resource 'command' parameter to manage state via `psmodule_manage.ps1.epp` template
- [X] T020 [US1] Add example to `examples/psmodule.pp`: basic installation from PowerShell Gallery

### Validation for User Story 1

- [X] T021 [US1] Run `pdk test unit --tests=spec/defines/psmodule_spec.rb` and verify all tests pass
- [X] T022 [US1] Run `pdk validate` and verify zero offenses
- [ ] T023 [US1] Manual test: Apply example manifest and verify PSDesiredStateConfiguration installs
- [ ] T024 [US1] Manual test: Re-apply manifest and verify idempotency (no changes)

**Checkpoint**: User Story 1 complete - basic module installation working and tested ✅

---

## Phase 4: User Story 2 - Remove Specified PowerShell Modules (Priority: P2)

**Goal**: Enable administrators to remove PowerShell modules explicitly declared with `ensure => absent`, maintaining clean system state

**Independent Test**: Install a module, change to `ensure => absent`, apply catalog, verify module removed via `Get-InstalledModule`

### Tests for User Story 2 (TDD - Write First) ✅

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T025 [P] [US2] Add test case: module removal with ensure => absent in `spec/defines/psmodule_spec.rb`
- [ ] T026 [P] [US2] Add test case: idempotency when module already absent in `spec/defines/psmodule_spec.rb`
- [ ] T027 [P] [US2] Add test case: module removal proceeds regardless of usage in `spec/defines/psmodule_spec.rb`

### Implementation for User Story 2

- [ ] T028 [US2] Extend `templates/psmodule_manage.ps1.epp` to handle ensure => absent with Uninstall-Module
- [ ] T029 [US2] Extend `templates/psmodule_check.ps1.epp` to check absence state correctly
- [ ] T030 [US2] Update exec resource in `manifests/psmodule.pp` to handle absent state
- [ ] T031 [US2] Add example to `examples/psmodule.pp`: module removal scenario

### Validation for User Story 2

- [ ] T032 [US2] Run `pdk test unit --tests=spec/defines/psmodule_spec.rb` and verify all tests pass
- [ ] T033 [US2] Manual test: Install module, then remove it, verify successful removal
- [ ] T034 [US2] Manual test: Remove non-existent module, verify idempotency (no changes)

**Checkpoint**: User Story 2 complete - module removal working and tested ✅

---

## Phase 5: User Story 3 - Query Installed DSC Resources (Priority: P3)

**Goal**: Provide administrators visibility into installed PowerShell modules via structured fact, enabling discovery and troubleshooting

**Independent Test**: Install modules, query `$facts['dsc_modules']`, verify accurate listing of installed modules

### Tests for User Story 3 (TDD - Write First) ✅

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T035 [P] [US3] Create unit test file `spec/unit/facter/dsc_modules_spec.rb` with test scaffolding
- [ ] T036 [P] [US3] Add test case: fact returns empty array when no modules installed in `spec/unit/facter/dsc_modules_spec.rb`
- [ ] T037 [P] [US3] Add test case: fact returns array of module hashes when modules installed in `spec/unit/facter/dsc_modules_spec.rb`
- [ ] T038 [P] [US3] Add test case: fact confinement - only runs when dscv3_info exists in `spec/unit/facter/dsc_modules_spec.rb`
- [ ] T039 [P] [US3] Add test case: fact caching behavior in `spec/unit/facter/dsc_modules_spec.rb`

### Implementation for User Story 3

- [ ] T040 [US3] Create structured fact `lib/facter/dsc_modules.rb` with confinement on dscv3_info
- [ ] T041 [US3] Implement PowerShell execution in `lib/facter/dsc_modules.rb` using Get-InstalledModule
- [ ] T042 [US3] Implement JSON parsing in `lib/facter/dsc_modules.rb` to structure fact data
- [ ] T043 [US3] Implement cache logic in `lib/facter/dsc_modules.rb`: read/write cache file, TTL check
- [ ] T044 [US3] Implement cache invalidation in `templates/psmodule_manage.ps1.epp`: delete cache after install/uninstall
- [ ] T045 [US3] Add platform-specific cache paths in `lib/facter/dsc_modules.rb` (Windows vs Linux/macOS)
- [ ] T046 [US3] Add error handling in `lib/facter/dsc_modules.rb` for PowerShell failures

### Validation for User Story 3

- [ ] T047 [US3] Run `pdk test unit --tests=spec/unit/facter/dsc_modules_spec.rb` and verify all tests pass
- [ ] T048 [US3] Manual test: Install module, query fact, verify module appears in list
- [ ] T049 [US3] Manual test: Verify fact caching works (second query is fast)
- [ ] T050 [US3] Manual test: Install another module, verify cache invalidates and new module appears

**Checkpoint**: User Story 3 complete - discovery fact working and tested ✅

---

## Phase 6: User Story 4 - Install Custom/Local DSC Modules (Priority: P3)

**Goal**: Enable developers and enterprise users to install modules from local files or custom repositories, supporting offline and air-gapped environments

**Independent Test**: Specify `source => '/path/to/module.nupkg'` or `repository => 'CustomRepo'`, apply catalog, verify module installs from specified source

### Tests for User Story 4 (TDD - Write First) ✅

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T051 [P] [US4] Add test case: module installation from custom repository in `spec/defines/psmodule_spec.rb`
- [ ] T052 [P] [US4] Add test case: module installation from local .nupkg file in `spec/defines/psmodule_spec.rb`
- [ ] T053 [P] [US4] Add test case: mutual exclusivity validation (repository XOR source) in `spec/defines/psmodule_spec.rb`
- [ ] T054 [P] [US4] Add test case: source file existence validation in `spec/defines/psmodule_spec.rb`

### Implementation for User Story 4

- [ ] T055 [US4] Extend `templates/psmodule_manage.ps1.epp` to support -Repository parameter when specified
- [ ] T056 [US4] Extend `templates/psmodule_manage.ps1.epp` to handle local .nupkg file installation (copy to modules path)
- [ ] T057 [US4] Add source file validation to `manifests/psmodule.pp` using file_exists() function
- [ ] T058 [US4] Add repository/source mutual exclusivity validation to `manifests/psmodule.pp`
- [ ] T059 [US4] Add example to `examples/psmodule.pp`: custom repository installation
- [ ] T060 [US4] Add example to `examples/psmodule.pp`: local file installation

### Validation for User Story 4

- [ ] T061 [US4] Run `pdk test unit --tests=spec/defines/psmodule_spec.rb` and verify all tests pass
- [ ] T062 [US4] Manual test: Install module from custom repository (if available)
- [ ] T063 [US4] Manual test: Install module from local .nupkg file

**Checkpoint**: User Story 4 complete - custom sources working and tested ✅

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, examples, and final validation

- [ ] T064 [P] Generate REFERENCE.md using `puppet strings generate --format markdown`
- [ ] T065 [P] Add comprehensive examples to `examples/psmodule.pp`: upgrade scenario
- [ ] T066 [P] Update module README.md with dsc::psmodule usage section
- [ ] T067 [P] Update CHANGELOG.md with new feature entry
- [ ] T068 Run full test suite: `pdk test unit` and verify 100% pass rate
- [ ] T069 Run PDK validation: `pdk validate` and verify zero offenses
- [ ] T070 [P] Add error message improvements for common failure scenarios in `manifests/psmodule.pp`
- [ ] T071 [P] Add logging/debug output to PowerShell templates for troubleshooting

**Final Checkpoint**: Feature complete, documented, and validated ✅

---

## Dependencies & Execution Order

### Critical Path (Must Complete in Order)

1. **Phase 1** (Setup) → **Phase 2** (Foundation) → **Phase 3** (US1 - MVP)
2. After Phase 3 (MVP), remaining user stories can proceed in parallel or priority order:
   - **Phase 4** (US2) - Independent of US3/US4
   - **Phase 5** (US3) - Independent of US2/US4
   - **Phase 6** (US4) - Independent of US2/US3
3. **Phase 7** (Polish) - After all user stories complete

### Parallel Execution Opportunities

**Within Phase 3 (US1 - Tests)**: Tasks T007-T012 can all run in parallel (different test cases)

**Within Phase 3 (US1 - Examples)**: Task T020 can run in parallel with validation tasks

**Within Phase 5 (US3 - Tests)**: Tasks T035-T039 can all run in parallel (different test cases)

**Within Phase 6 (US4 - Tests)**: Tasks T051-T054 can all run in parallel (different test cases)

**Within Phase 7 (Polish)**: Tasks T064-T067 can all run in parallel (different files)

### User Story Independence

- **US1 (Phase 3)**: Foundational - must complete first for MVP
- **US2 (Phase 4)**: Depends on US1 (extends same files)
- **US3 (Phase 5)**: Independent - can run after foundation (Phase 2)
- **US4 (Phase 6)**: Depends on US1 (extends same files)

**Recommended Execution**: Complete US1 first (MVP), then US2, US3, US4 can proceed in any order

---

## Implementation Strategy

### Minimum Viable Product (MVP)

**MVP = Phase 1 + Phase 2 + Phase 3 (User Story 1)**

This delivers core value:
- Install PowerShell modules from Gallery
- Exact version specification
- Idempotent installation
- Basic validation and error handling

**Time Estimate**: ~2-3 hours including tests

### Incremental Delivery

1. **Sprint 1**: MVP (Phases 1-3) - Deploy and gather feedback
2. **Sprint 2**: US2 (Phase 4) - Module removal capability
3. **Sprint 3**: US3 (Phase 5) - Discovery fact for visibility
4. **Sprint 4**: US4 (Phase 6) - Offline/custom source support
5. **Sprint 5**: Phase 7 - Polish and documentation

### Testing Strategy

**Unit Testing** (rspec-puppet + rspec):
- Defined type parameter validation
- Catalog compilation
- Resource declarations
- Fact logic and caching

**Integration Testing** (manual):
- Real PowerShell execution on Windows
- Cross-platform testing (Linux with PowerShell 7+)
- Idempotency verification
- Error scenario validation

**Performance Testing**:
- Fact caching effectiveness
- Module installation timing
- Large module handling (up to 50MB)

---

## Task Summary

**Total Tasks**: 71
- Phase 1 (Setup): 3 tasks
- Phase 2 (Foundation): 3 tasks
- Phase 3 (US1 - MVP): 18 tasks
- Phase 4 (US2): 10 tasks
- Phase 5 (US3): 16 tasks
- Phase 6 (US4): 13 tasks
- Phase 7 (Polish): 8 tasks

**Parallel Tasks**: 29 tasks marked [P] (41% can run in parallel)

**Test Tasks**: 23 tasks (32% of total) - Following TDD constitution requirement

**MVP Tasks**: 24 tasks (Phases 1-3) - Delivers core installation functionality

**Estimated Total Time**: 
- MVP: 2-3 hours
- Full Feature: 6-8 hours (including all user stories and polish)

---

## Validation Checklist

Before marking feature complete, verify:

- [ ] All 71 tasks completed and checked off
- [ ] `pdk test unit` passes with 100% success rate
- [ ] `pdk validate` reports zero offenses  
- [ ] All 4 user stories independently tested and working
- [ ] REFERENCE.md generated with Puppet Strings
- [ ] Examples work on actual Puppet deployment
- [ ] Cross-platform testing completed (Windows + Linux/macOS if available)
- [ ] Performance targets met (5 min install for 50MB, <2s fact with cache)
- [ ] Error messages clear and actionable
- [ ] Documentation complete (README, CHANGELOG, examples)

---

**Status**: Ready for implementation  
**Next Command**: `/speckit.implement` to begin TDD execution
