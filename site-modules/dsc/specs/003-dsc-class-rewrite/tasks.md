# Implementation Tasks: DSC Class Reimplementation

**Feature**: 003-dsc-class-rewrite  
**Branch**: `003-dsc-class-rewrite`  
**Status**: Ready for Implementation

## Overview

This document breaks down the DSC class reimplementation into discrete, executable tasks following test-first development principles. Based on the research findings, the existing architecture is sound - we're focusing on refinement: adding binary validation, improving error handling, and enhancing documentation.

## Task Execution Order

Tasks are organized into phases. Complete each phase before moving to the next unless marked with [P] for parallel execution.

**Legend**:
- ✅ = Completed
- ⏳ = In Progress  
- [ ] = Not Started
- [P] = Can run in parallel with other [P] tasks in same phase

---

## Phase 0: Prerequisites & Validation

### Task 0.1: Verify Development Environment
- [ ] Verify Puppet Agent 8.x available
- [ ] Verify PDK 3.4.0+ installed (`pdk --version`)
- [ ] Verify Ruby 2.7+ available
- [ ] Verify git branch is `003-dsc-class-rewrite`
- [ ] Verify rspec-puppet and rspec gems available

**Validation**: All tools present and accessible  
**Estimated Time**: 5 minutes

---

## Phase 1: Analyze Existing Implementation

### Task 1.1: Code Review - manifests/init.pp
- [ ] Read current `manifests/init.pp` implementation (lines 1-200)
- [ ] Identify areas needing refinement per research.md
- [ ] Document current idempotency approach (`creates` parameter usage)
- [ ] Note error handling gaps

**Validation**: Understanding of current implementation documented  
**Estimated Time**: 15 minutes

### Task 1.2: Code Review - Custom Fact
- [ ] Read `lib/facter/dsc_install_path.rb` implementation
- [ ] Verify external fact file reading logic
- [ ] Check error handling (file not found, malformed JSON, etc.)
- [ ] Confirm platform detection logic

**Validation**: Fact implementation understood  
**Estimated Time**: 10 minutes

### Task 1.3: Code Review - Provider Integration
- [ ] Read `lib/puppet/provider/dsc_resource/dsc_resource.rb` (focus on `dsc_binary_path` method)
- [ ] Verify custom fact integration
- [ ] Check fallback to platform defaults
- [ ] Confirm binary path construction

**Validation**: Provider integration understood  
**Estimated Time**: 10 minutes

---

## Phase 2: Test Improvements (Test-First)

### Task 2.1: Review Existing Tests - Manifest
- [ ] Read `spec/classes/init_spec.rb`
- [ ] Identify test coverage gaps for new validation logic
- [ ] Document tests that need updates

**Validation**: Test gaps identified  
**Estimated Time**: 10 minutes

### Task 2.2: Add Tests - Binary Validation
- [ ] Add test: "validates DSC binary is functional after installation"
- [ ] Add test: "provides clear error if binary validation fails"
- [ ] Add test: "skips validation on subsequent runs (idempotent)"

**Files**: `spec/classes/init_spec.rb`  
**Validation**: Tests fail (Red phase - no implementation yet)  
**Estimated Time**: 20 minutes

### Task 2.3: Add Tests - Enhanced Error Messages
- [ ] Add test: "fails with clear message on unsupported architecture"
- [ ] Add test: "fails with clear message on network download errors"
- [ ] Add test: "fails with clear message on permission errors"

**Files**: `spec/classes/init_spec.rb`  
**Validation**: Tests fail (Red phase)  
**Estimated Time**: 15 minutes

---

## Phase 3: Implement Binary Validation

### Task 3.1: Add Binary Validation Logic
- [ ] Add `exec` resource that runs `dsc --version` or `dsc -v`
- [ ] Use `unless` parameter to check if validation already passed
- [ ] Set `require` to depend on binary extraction
- [ ] Set appropriate timeout (30 seconds)
- [ ] Add to both Windows and Unix code paths

**Files**: `manifests/init.pp`  
**Code Location**: After extraction, before fact file creation  
**Validation**: Tests pass (Green phase)  
**Estimated Time**: 25 minutes

### Task 3.2: Test Binary Validation Implementation
- [ ] Run `pdk test unit` for manifest tests
- [ ] Verify binary validation tests pass
- [ ] Verify no regressions in existing tests

**Validation**: All tests passing  
**Estimated Time**: 10 minutes

---

## Phase 4: Enhance Error Handling

### Task 4.1: Add Architecture Detection Error Messages
- [ ] Update architecture case statement
- [ ] Replace generic `fail()` with descriptive message
- [ ] Include supported architectures in error message
- [ ] Include actual detected architecture in error

**Files**: `manifests/init.pp` (around line 46-49)  
**Validation**: Error message clarity improved  
**Estimated Time**: 10 minutes

### Task 4.2: Add Platform Detection Error Messages
- [ ] Update kernel case statements (multiple locations)
- [ ] Provide clear error messages for unsupported platforms
- [ ] Include minimum version requirements (Windows 10+, etc.)
- [ ] Include actual detected platform in error

**Files**: `manifests/init.pp` (around line 52-76)  
**Validation**: Error messages are actionable  
**Estimated Time**: 15 minutes

### Task 4.3: Add Download Failure Handling
- [ ] Add `onlyif` or `unless` checks for network connectivity
- [ ] Improve error output with `logoutput => true` (already present)
- [ ] Consider adding timeout parameters to download execs
- [ ] Document common failure scenarios in comments

**Files**: `manifests/init.pp` (exec resources)  
**Validation**: Error handling comprehensive  
**Estimated Time**: 20 minutes

### Task 4.4: Test Error Handling
- [ ] Run `pdk test unit` for error handling tests
- [ ] Verify enhanced error message tests pass
- [ ] Manually test error scenarios if possible

**Validation**: All error handling tests pass  
**Estimated Time**: 10 minutes

---

## Phase 5: Documentation Enhancements

### Task 5.1: Update Puppet Strings - manifests/init.pp
- [ ] Review existing `@summary` and `@param` annotations
- [ ] Add `@example` for validation behavior
- [ ] Document two-run convergence pattern
- [ ] Add notes about error messages

**Files**: `manifests/init.pp` (top comment block)  
**Validation**: Documentation complete and accurate  
**Estimated Time**: 20 minutes

### Task 5.2: Add Inline Comments - Complex Logic
- [ ] Add comments explaining architecture detection mapping
- [ ] Add comments explaining platform string construction
- [ ] Add comments for binary validation logic
- [ ] Add comments for fact file creation purpose

**Files**: `manifests/init.pp`  
**Validation**: Code is self-documenting  
**Estimated Time**: 15 minutes

### Task 5.3: Update Examples - Show Validation
- [ ] Review `examples/init.pp` and `examples/dsc_with_custom_path.pp`
- [ ] Ensure examples mention two-run requirement
- [ ] Add comments about binary validation
- [ ] Verify examples are current with parameter names

**Files**: `examples/*.pp`  
**Validation**: Examples are accurate and helpful  
**Estimated Time**: 15 minutes

---

## Phase 6: Code Quality & Validation

### Task 6.1: Run PDK Validation
- [ ] Run `pdk validate --parallel`
- [ ] Fix any puppet-lint offenses
- [ ] Fix any RuboCop offenses
- [ ] Fix any metadata or YAML syntax errors

**Validation**: Zero offenses reported  
**Estimated Time**: 15 minutes

### Task 6.2: Run Full Test Suite
- [ ] Run `pdk test unit`
- [ ] Verify all rspec-puppet tests pass
- [ ] Verify all rspec tests pass (fact, provider)
- [ ] Check test coverage meets requirements

**Validation**: All tests passing, good coverage  
**Estimated Time**: 10 minutes

### Task 6.3: Generate Documentation
- [ ] Run `puppet strings generate`
- [ ] Review generated reference documentation
- [ ] Verify custom fact documentation included
- [ ] Verify all parameters documented

**Validation**: Documentation generated successfully  
**Estimated Time**: 5 minutes

---

## Phase 7: Integration Testing & Manual Verification

### Task 7.1: Build Module Package
- [ ] Run `pdk build`
- [ ] Verify tarball created in `pkg/`
- [ ] Check tarball contents include all necessary files

**Validation**: Module builds successfully  
**Estimated Time**: 5 minutes

### Task 7.2: Review Changes Against Spec
- [ ] Compare implementation to spec.md requirements
- [ ] Verify all functional requirements met (FR-001 through FR-014)
- [ ] Check success criteria can be validated
- [ ] Confirm edge cases addressed

**Validation**: Implementation matches specification  
**Estimated Time**: 20 minutes

### Task 7.3: Update Checklist Status
- [ ] Update `checklists/requirements.md` if exists
- [ ] Mark completed items
- [ ] Note any deviations from original spec
- [ ] Document any additional features added

**Validation**: Checklist reflects actual implementation  
**Estimated Time**: 10 minutes

---

## Phase 8: Final Review & Cleanup

### Task 8.1: Code Refactoring
- [ ] Review all changed files for clarity
- [ ] Simplify any overly complex logic
- [ ] Ensure idiomatic Puppet code
- [ ] Apply DRY principle where appropriate

**Validation**: Code is clean and maintainable  
**Estimated Time**: 20 minutes

### Task 8.2: Commit Changes
- [ ] Stage all modified files (`git add`)
- [ ] Write descriptive commit message
- [ ] Include reference to feature 003
- [ ] Mention key improvements (validation, errors, docs)

**Validation**: Changes committed to branch  
**Estimated Time**: 10 minutes

### Task 8.3: Final Validation
- [ ] Re-run `pdk validate` (one final check)
- [ ] Re-run `pdk test unit` (one final check)
- [ ] Verify no regressions introduced
- [ ] Confirm all Phase 0-8 tasks completed

**Validation**: Ready for merge/review  
**Estimated Time**: 10 minutes

---

## Summary

**Total Tasks**: 28  
**Estimated Total Time**: 5-6 hours  
**Critical Path**: Phase 2 → Phase 3 → Phase 4 (TDD cycle)  
**Parallel Opportunities**: None in this feature (single file changes)

## Success Criteria

- [ ] All 28 tasks completed
- [ ] Zero PDK validation offenses
- [ ] All unit tests passing
- [ ] Binary validation implemented and tested
- [ ] Error messages improved and tested  
- [ ] Documentation enhanced (Puppet Strings + examples)
- [ ] Code committed to `003-dsc-class-rewrite` branch

## Notes

This implementation focuses on refinement rather than restructuring. The research phase confirmed the existing architecture is sound. We're adding:

1. **Binary Validation**: Verify DSC works after installation
2. **Better Errors**: Clear, actionable error messages
3. **Enhanced Docs**: Puppet Strings, inline comments, examples

The implementation follows strict TDD: write failing tests first (Phase 2), then implement to make them pass (Phases 3-4).
