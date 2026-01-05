<!--
Sync Impact Report:
Version Change: [TEMPLATE] → 1.0.0
Constitution Ratified: 2025-11-10
Changes:
- Initialized constitution for puppetlabs-dsc module
- Defined 5 core principles for Puppet development
- Established PDK compliance as foundation
- Mandated test-first discipline with rspec-puppet
- Required Puppet Strings documentation
- Enforced zero-tolerance quality gates
- Established code quality standards

Templates Requiring Updates:
⚠ .specify/templates/plan-template.md - Should include PDK validation and rspec-puppet testing requirements
⚠ .specify/templates/spec-template.md - Should reference constitution principles in requirements
⚠ .specify/templates/tasks-template.md - Should include tasks for: PDK validation, rspec-puppet tests, Puppet Strings docs, quality gates

Follow-up TODOs:
- Review existing module code for constitution compliance
- Ensure metadata.json has version-pinned dependencies
- Verify all code passes pdk validate with zero offenses
- Audit test coverage and test-first discipline adherence
-->

# puppetlabs-dsc Constitution

## Core Principles

### I. Puppet Standards and Puppet Development Kit (PDK)

All Puppet code MUST adhere to [Puppet Development Kit (PDK)](https://help.puppet.com/pdk/current/topics/pdk.htm) standards and conventions.

**Requirements:**
- Use PDK for module scaffolding, testing, and validation
- Follow PDK directory structure and file naming conventions
- Utilize PDK commands for all development workflow tasks
- Maintain compatibility with PDK 3.4.0 or newer

**Rationale:** PDK provides standardized tooling and conventions that ensure consistency across Puppet modules, reduce configuration overhead, and integrate quality checks into the development workflow.

### II. Test-Driven Development with rspec-puppet

Testing is **mandatory** and MUST follow strict test-first discipline using [rspec-puppet](https://rspec-puppet.com/documentation/).

**Requirements:**
- Tests MUST be written before implementation code (Red-Green-Refactor)
- All classes, defined types, custom types, and providers require comprehensive test coverage
- Tests MUST validate expected catalog compilation, resource declarations, and parameter handling
- Integration tests required for cross-resource dependencies and complex behaviors
- All tests MUST pass before code review or merge

**Rationale:** Test-first development catches errors early, documents expected behavior, enables safe refactoring, and ensures reliability of infrastructure code that manages critical systems.

### III. Documentation Standards with Puppet Strings

All Puppet code MUST be documented following [Puppet Strings](https://help.puppet.com/core/8/Content/PuppetCore/puppet_strings.htm) formatting.

**Requirements:**
- All classes, defined types, functions, types, and providers MUST include Puppet Strings annotations
- Documentation MUST include: summary, description, parameter types and descriptions, return values (for functions), examples demonstrating common usage
- Generate reference documentation via `puppet strings generate` before releases
- Keep documentation synchronized with code changes

**Rationale:** Puppet Strings provides machine-readable documentation that generates consistent reference material, enables IDE integration, and ensures maintainers understand code intent without archaeology.

### IV. Validation and Quality Gates (NON-NEGOTIABLE)

All code MUST pass validation checks with **zero offenses** before commit.

**Required Validations:**
- **`pdk validate`**: MUST report zero offenses across all validators
- **RuboCop**: All Ruby code (types, providers, unit tests) MUST pass style checks with zero offenses
- **puppet-lint**: All Puppet manifests MUST pass with zero warnings
- **Metadata Validation**: `metadata.json` MUST pass PDK schema validation
- **YAML Syntax**: All YAML files MUST be syntactically valid
- **Syntax Checks**: All Puppet manifests, Ruby code, and templates MUST be syntactically valid
- **Dependencies**: All module dependencies MUST be explicitly declared and version-pinned in `metadata.json`

**Enforcement:**
- Pre-commit hooks SHOULD run `pdk validate`
- CI/CD pipelines MUST fail builds on validation errors
- No exceptions without documented justification and remediation plan

**Rationale:** Zero-tolerance quality gates prevent technical debt accumulation, ensure consistent code style, catch errors before production, and maintain module integrity across Puppet versions.

### V. Code Quality and Idiomatic Puppet

Code MUST be clear, maintainable, and follow Puppet idioms and best practices.

**Requirements:**
- Prefer declarative resource management over imperative exec resources
- Use Puppet data types for parameter validation
- Follow the principle of least privilege in resource declarations
- Avoid unnecessary complexity; favor composition over monolithic classes
- Use Hiera for data separation when appropriate
- Apply the Puppet Style Guide for naming and structure
- Ensure idempotency: repeated runs produce identical results

**Rationale:** Idiomatic Puppet code is easier to understand, debug, and extend. It leverages the platform's strengths and avoids common antipatterns that lead to brittle infrastructure.

## Technology Stack

**Module Framework:**
- Puppet Development Kit (PDK) ≥ 3.4.0
- Puppet Agent: ≥ 8.0.0, < 9.0.0
- Puppet Strings for code annotations and reference generation

**Testing Framework:**
- rspec-puppet for unit testing
- rspec for Ruby code testing
- PDK built-in test harness

**Validation Tools:**
- PDK validate (orchestrates all validators)
- RuboCop (Ruby style)
- puppet-lint (Puppet manifest style)
- metadata-json-lint (metadata validation)

## Development Workflow

**Pre-Implementation:**
1. Write rspec-puppet tests that define expected behavior
2. Verify tests fail (Red phase)
3. Obtain approval from stakeholders/reviewers if applicable

**Implementation:**
4. Write minimal code to pass tests (Green phase)
5. Refactor for clarity and maintainability
6. Add Puppet Strings documentation
7. Run `pdk validate` and resolve all offenses

**Pre-Commit:**
8. Verify all tests pass
9. Verify `pdk validate` reports zero offenses
10. Update CHANGELOG.md with changes
11. Commit with descriptive message following conventional commits

**Review Process:**
- All changes require peer review
- Reviewer MUST verify constitution compliance
- Reviewer MUST verify test coverage and quality
- Reviewer MUST verify documentation completeness

## Governance

**Constitution Authority:**
- This constitution supersedes conflicting practices or conventions
- All pull requests and code reviews MUST verify compliance with these principles
- Deviations require documented justification, risk assessment, and remediation plan

**Amendment Process:**
- Amendments require: written proposal with rationale, impact analysis on existing code, approval from module maintainers, migration plan for non-compliant code (if applicable)
- Version increments follow semantic versioning:
  - **MAJOR**: Backward-incompatible principle changes or removals
  - **MINOR**: New principles or material expansions
  - **PATCH**: Clarifications, wording improvements, non-semantic refinements

**Compliance Review:**
- Regular audits of module code against constitution principles
- Automated CI/CD checks enforce Principle IV (Validation and Quality Gates)
- Technical debt from non-compliance MUST be tracked and prioritized

**Continuous Improvement:**
- Constitution reviewed quarterly or when major Puppet/PDK versions released
- Lessons learned from incidents or challenging implementations inform amendments
- Community feedback and Puppet best practice evolution guide updates

---

**Version**: 1.0.0 | **Ratified**: 2025-11-10 | **Last Amended**: 2025-11-10
