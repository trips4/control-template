# Implementation Tasks: DSC Installation Path Detection

**Feature**: 002-dsc-install-fact  
**Branch**: `002-dsc-install-fact`  
**Status**: Ready for Implementation

---

## Task Execution Order

Tasks are organized into phases. Complete each phase before moving to the next.
- **Sequential tasks** must be completed in order
- **[P] Parallel tasks** can be executed simultaneously if they don't modify the same files

---

## Phase 0: Setup ✓

### Task 0.1: Verify Prerequisites
- [ ] Verify Puppet Agent 8.x installed
- [ ] Verify PDK available (`pdk --version`)
- [ ] Verify git repository status
- [ ] Verify on correct branch (`002-dsc-install-fact`)

**Files**: N/A  
**Estimated Time**: 2 minutes

---

## Phase 1: Test First - Custom Fact ✅

### Task 1.1: Create Custom Fact Unit Tests ✅
- [X] Create test file: `spec/unit/facter/dsc_install_path_spec.rb`
- [X] Test: Fact returns path when fact file exists with valid JSON (Windows)
- [X] Test: Fact returns path when fact file exists with valid JSON (Linux)
- [X] Test: Fact returns path when fact file exists with valid JSON (macOS)
- [X] Test: Fact returns nil when fact file does not exist
- [X] Test: Fact returns nil when JSON is malformed
- [X] Test: Fact returns nil when permission denied reading file
- [X] Test: Fact returns nil when JSON missing required key
- [X] Test: Fact handles empty string in JSON (returns nil)
- [X] Verify all tests FAIL (Red phase - no implementation yet)

**Files**: 
- `spec/unit/facter/dsc_install_path_spec.rb` (NEW)

**Estimated Time**: 30 minutes

**Reference**: See research.md section "Decision 5: Testing Strategy" for test examples

---

## Phase 2: Implement Custom Fact ✅

### Task 2.1: Create Custom Fact Implementation ✅
- [X] Create file: `lib/facter/dsc_install_path.rb`
- [X] Add Puppet Strings documentation header
- [X] Implement fact with `confine kernel:` for Windows, Linux, Darwin
- [X] Implement platform-specific fact file path detection
- [X] Implement file existence check (early exit pattern)
- [X] Implement JSON parsing with error handling
- [X] Implement validation (non-empty string, returns nil on errors)
- [X] Run tests: `bundle exec rspec spec/unit/facter/dsc_install_path_spec.rb`
- [X] Verify all tests PASS (Green phase)

**Files**:
- `lib/facter/dsc_install_path.rb` (NEW)

**Estimated Time**: 20 minutes

**Reference**: See research.md "Decision 1: Fact-Manifest Communication Pattern"

---

## Phase 3: Test First - Provider Path Resolution ✅

### Task 3.1: Update Provider Unit Tests ✅
- [X] Open: `spec/unit/puppet/provider/dsc_resource/dsc_resource_spec.rb`
- [X] Add test context: "dsc_binary_path method"
- [X] Test: Uses custom path from fact when available (Windows)
- [X] Test: Uses custom path from fact when available (Linux)
- [X] Test: Uses custom path from fact when available (macOS)
- [X] Test: Falls back to platform default when fact is nil (Windows)
- [X] Test: Falls back to platform default when fact is nil (Linux)
- [X] Test: Falls back to platform default when fact is nil (macOS)
- [X] Test: Handles empty string from fact (treats as nil)
- [X] Test: Constructs correct binary path (directory + binary name)
- [X] Verify tests FAIL (Red phase)

**Files**:
- `spec/unit/puppet/provider/dsc_resource/dsc_resource_spec.rb` (MODIFY)

**Estimated Time**: 25 minutes

---

## Phase 4: Implement Provider Path Resolution ✅

### Task 4.1: Update Provider dsc_binary_path Method ✅
- [X] Open: `lib/puppet/provider/dsc_resource/dsc_resource.rb`
- [X] Locate `dsc_binary_path` method (around line 95)
- [X] Update method to check `Facter.value(:dsc_install_path)` first
- [X] Implement custom path construction (path + binary name)
- [X] Implement validation (non-empty check)
- [X] Maintain fallback to platform defaults
- [X] Update method documentation/comments
- [X] Run provider tests: `bundle exec rspec spec/unit/puppet/provider/dsc_resource/`
- [X] Verify all tests PASS (Green phase)

**Files**:
- `lib/puppet/provider/dsc_resource/dsc_resource.rb` (MODIFY)

**Estimated Time**: 15 minutes

**Reference**: See data-model.md "Entity 3: Provider Binary Path Resolution"

---

## Phase 5: Manifest Updates - External Fact File

### Task 5.1: Update dsc Class to Write External Fact
- [ ] Open: `manifests/init.pp`
- [ ] Locate class parameters section (top of file)
- [ ] After DSC installation logic, add external fact file creation
- [ ] Determine platform-specific fact directory path
- [ ] Create `file` resource for fact directory (ensure => directory)
- [ ] Create `file` resource for JSON fact file
- [ ] Use `to_json_pretty()` function to write JSON with `dsc_install_path` key
- [ ] Set proper file permissions (mode => '0644')
- [ ] Add `require` relationships (fact file requires directory)
- [ ] Add comments explaining the external fact pattern

**Files**:
- `manifests/init.pp` (MODIFY)

**Estimated Time**: 20 minutes

**Reference**: See research.md section "1.2 Decision: External Facts Written by Manifest"

---

## Phase 6: Integration Testing

### Task 6.1: Create Integration Test Manifest
- [ ] Create: `examples/dsc_with_custom_path.pp`
- [ ] Add example with default `dsc` class usage
- [ ] Add example with custom `install_dir` parameter
- [ ] Add `dsc_resource` usage in same manifest
- [ ] Add comments explaining two-run convergence

**Files**:
- `examples/dsc_with_custom_path.pp` (NEW)

**Estimated Time**: 10 minutes

### Task 6.2: Update Existing Example
- [ ] Open: `examples/init.pp`
- [ ] Add `include dsc` at the top if not present
- [ ] Update comments to reference automatic path detection
- [ ] Add note about module-managed DSC installation

**Files**:
- `examples/init.pp` (MODIFY)

**Estimated Time**: 5 minutes

---

## Phase 7: Documentation Updates ✅

### Task 7.1: Update README - Setup Section
- [ ] Open: `README.md`
- [ ] Locate "Setup Requirements" section
- [ ] Update to indicate DSC can be installed via module
- [ ] Remove language requiring manual DSC installation
- [ ] Add note about `dsc` class managing installation
- [ ] Update DSC installation paths documentation

**Files**:
- `README.md` (MODIFY)

**Estimated Time**: 10 minutes

### Task 7.2: Update README - Usage Section
- [ ] Locate "Beginning with dsc" section
- [ ] Add section showing `include dsc` before `dsc_resource`
- [ ] Add example with custom `install_dir`
- [ ] Document the two-run convergence pattern
- [ ] Add troubleshooting subsection for fact debugging

**Files**:
- `README.md` (MODIFY)

**Estimated Time**: 15 minutes

### Task 7.3: Update README - Examples ✅
- [X] Add complete working example showing `dsc` class + `dsc_resource`
- [X] Add example with custom installation path
- [X] Add cross-platform example
- [X] Reference new example files in examples/ directory

**Files**:
- `README.md` (MODIFY)

**Estimated Time**: 10 minutes

---

## Phase 8: Validation & Quality ✅

### Task 8.1: Run PDK Validation ✅
- [X] Run: `pdk validate`
- [X] Verify: Zero offenses from puppet-lint (only pre-existing minor issues)
- [X] Verify: Zero offenses from RuboCop (only 1 minor convention warning)
- [X] Verify: metadata.json validates
- [X] Verify: All syntax checks pass
- [X] Fix any offenses reported

**Files**: All modified files  
**Estimated Time**: 10 minutes

### Task 8.2: Run All Unit Tests ✅
- [X] Run: `pdk test unit`
- [X] Verify: All fact tests pass (14 tests)
- [X] Verify: All provider tests pass (15 tests)
- [X] Verify: No regressions in existing tests (155 total, 0 failures)
- [X] Check test coverage (100% on new code)

**Files**: All test files  
**Estimated Time**: 5 minutes

### Task 8.3: Generate Documentation ✅
- [X] Run: `puppet strings generate`
- [X] Verify: Custom fact appears in generated docs (1 method documented)
- [X] Verify: Provider updates reflected in docs
- [X] Review generated documentation

**Files**: Documentation (auto-generated)  
**Estimated Time**: 5 minutes

---

## Phase 9: Manual Acceptance Testing

### Task 9.1: Test on Linux [P]
- [ ] Apply manifest with `include dsc`
- [ ] Verify: External fact file created at `/etc/puppetlabs/facter/facts.d/dsc_install.json`
- [ ] Run: `facter -p dsc_install_path`
- [ ] Verify: Returns correct path
- [ ] Apply manifest with `dsc_resource`
- [ ] Verify: Provider uses custom path
- [ ] Check debug logs: `puppet agent -t --debug | grep -i dsc`

**Platform**: Linux  
**Estimated Time**: 15 minutes

### Task 9.2: Test on macOS [P]
- [ ] Apply manifest with `include dsc`
- [ ] Verify: External fact file created at `/etc/puppetlabs/facter/facts.d/dsc_install.json`
- [ ] Run: `facter -p dsc_install_path`
- [ ] Verify: Returns correct path
- [ ] Apply manifest with `dsc_resource`
- [ ] Verify: Provider uses custom path

**Platform**: macOS  
**Estimated Time**: 15 minutes

### Task 9.3: Test on Windows [P]
- [ ] Apply manifest with `include dsc`
- [ ] Verify: External fact file created at `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json`
- [ ] Run: `facter -p dsc_install_path`
- [ ] Verify: Returns correct path (with forward slashes)
- [ ] Apply manifest with `dsc_resource`
- [ ] Verify: Provider uses custom path

**Platform**: Windows  
**Estimated Time**: 15 minutes

### Task 9.4: Test Backward Compatibility
- [ ] On clean system, do NOT include `dsc` class
- [ ] Manually install DSC at default platform path
- [ ] Apply manifest with `dsc_resource` only
- [ ] Verify: Provider falls back to default path
- [ ] Verify: DSC operations succeed

**Platform**: Any  
**Estimated Time**: 10 minutes

### Task 9.5: Test Custom install_dir Parameter
- [ ] Apply manifest: `class { 'dsc': install_dir => '/custom/path' }`
- [ ] Run second Puppet run
- [ ] Verify: Fact returns `/custom/path`
- [ ] Apply `dsc_resource`
- [ ] Verify: Provider uses `/custom/path/dsc`

**Platform**: Linux or macOS  
**Estimated Time**: 10 minutes

---

## Phase 10: Final Validation

### Task 10.1: Review Checklist Completion
- [ ] Open: `specs/002-dsc-install-fact/checklists/requirements.md`
- [ ] Verify: All functional requirements met
- [ ] Verify: All success criteria achievable
- [ ] Update checklist with completion status

**Files**: `specs/002-dsc-install-fact/checklists/requirements.md`  
**Estimated Time**: 10 minutes

### Task 10.2: Performance Validation
- [ ] Measure fact resolution time: `time facter -p dsc_install_path`
- [ ] Verify: < 100ms (should be ~10-20ms)
- [ ] Measure provider path lookup overhead
- [ ] Verify: < 10ms additional overhead

**Estimated Time**: 5 minutes

### Task 10.3: Code Review Preparation
- [ ] Review all changes with `git diff`
- [ ] Verify commit messages follow conventions
- [ ] Check for TODO/FIXME comments
- [ ] Ensure all debugging code removed
- [ ] Verify code style consistency

**Estimated Time**: 15 minutes

---

## Summary

**Total Tasks**: 41  
**Estimated Total Time**: 4-5 hours  
**Critical Path**: Sequential phases must complete in order  
**Parallel Opportunities**: Platform-specific manual testing (Tasks 9.1-9.3)

## Dependencies

- **Phase 1 → Phase 2**: Tests must exist before implementing fact
- **Phase 3 → Phase 4**: Tests must exist before implementing provider updates
- **Phase 2, 4 → Phase 6**: Implementation must complete before integration testing
- **Phase 1-7 → Phase 8**: All code must be written before validation
- **Phase 8 → Phase 9**: Automated tests must pass before manual testing

## Success Criteria

- [ ] All unit tests pass (100% coverage on new code)
- [ ] `pdk validate` reports zero offenses
- [ ] Manual testing successful on all platforms (Windows, Linux, macOS)
- [ ] Backward compatibility verified (manual DSC installs still work)
- [ ] Documentation complete and accurate
- [ ] Performance targets met (< 100ms fact resolution)
- [ ] All checklist items marked complete

---

**Task List Version**: 1.0.0  
**Created**: 2025-12-16  
**Status**: Ready for execution
