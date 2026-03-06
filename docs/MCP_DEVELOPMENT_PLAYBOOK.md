# MCP Development Playbook

This playbook defines how Kadmat should use available MCP servers to deliver a consistent, production-grade product without random UI drift.

## 1. Objective

- Build features from a single source of truth (spec + design + task tracking).
- Enforce design consistency via shared tokens/components.
- Keep CI green while delivering fast iterations.
- Track operational quality after rollout.

## 2. MCP Stack Mapping

Use each MCP tool only for the concern it owns:

- `figma` / `figma-implement-design`
  - Source of truth for visual design.
  - Extract spacing, typography, color, and component structure.
  - Implement screens node-by-node with high visual fidelity.
- `notion-spec-to-implementation`
  - Convert product requirements into implementation tasks.
  - Store acceptance criteria, edge cases, and rollout checklist.
- `linear`
  - Manage execution with prioritized tickets and clear ownership.
  - Each ticket should map to one deliverable and one PR.
- `gh-fix-ci`
  - Investigate failing checks in GitHub Actions.
  - Keep `main` stable and release-safe.
- `sentry`
  - Verify production behavior after release.
  - Track top errors and regressions per flow.

## 3. Delivery Workflow (Per Feature)

1. Product definition
   - Create/confirm feature spec in Notion.
   - Define acceptance criteria and non-functional constraints.

2. Design alignment
   - Pull exact Figma nodes and tokens.
   - Validate responsive behavior for mobile breakpoints.

3. Implementation
   - Reuse design-system components from `lib/src/core`.
   - Avoid ad-hoc styles directly in screens unless justified.

4. Verification
   - Run static checks and tests.
   - Validate flow with smoke tests when backend contracts are involved.

5. Merge and release
   - Merge only with green checks.
   - Monitor post-merge errors in Sentry.

## 4. Engineering Rules

- UI screens must consume shared tokens/components first.
- New visual patterns require adding/updating shared components, not copying styles.
- Every PR should include:
  - linked spec/ticket,
  - screenshots before/after (where relevant),
  - verification notes.

## 5. Sprint Template

Use this sprint sequence for major flows:

1. Foundation
   - update tokens/theme/components.
2. Customer flow
   - service request -> bidding -> completion.
3. Technician flow
   - dispatch feed -> progress -> completion.
4. Hardening
   - CI stability + smoke + monitoring.

## 6. Definition of Done

A feature is done only when:

- Acceptance criteria are met.
- Shared design system is respected.
- CI checks are green.
- Relevant tests pass.
- No blocking Sentry regression appears after rollout.
