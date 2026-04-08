# RenameMenu Repo Cleanup Work Order For Claude

Date: 2026-04-08
Scope: Tracked repo state only
Final cleanup requirement: archive this document out of the repo root when the work is complete

## Primary Goal

Keep RenameMenu easy to maintain and ship with:
- one root master document
- core app logic grouped cleanly
- install/uninstall scripts separated from app code
- config/examples/assets/tests organized under predictable folders

## Current Issues To Fix

1. The root mixes app code, installers, launchers, config, icons, logs, and platform-specific scripts.
2. The README is good user-facing documentation, but the repo structure should better reflect the actual product boundaries.
3. Runtime residue like `error.log` and ad hoc test files should not shape the active root layout.
4. The root should feel like a source repo, not a working directory.

## Work Order

### 1. Keep One Root Master Document
- Keep `README.md` as the main root-level document.
- Ensure it links clearly to installation, configuration, and contributor details.

### 2. Clean The Root Layout
- Group files by responsibility where practical:
  - core app logic
  - install/uninstall/platform integration scripts
  - docs
  - assets/icons
  - tests
- Keep the root limited to the master document and the most important entrypoints.

### 3. Remove Or Quarantine Runtime Residue
- Remove tracked logs or transient runtime files from the maintained root structure.
- Move ad hoc tests or scratch utilities into a proper `tests/` or `tools/` area if they are worth keeping.

### 4. Reconcile Script Surface
- Audit Windows/macOS/Linux install and uninstall scripts.
- Keep only current supported flows in active locations.
- Archive historical or redundant wrappers if needed.

### 5. Clarify Config Policy
- Keep example config and user config handling obvious.
- Ensure docs and file locations make it clear what is source, example, and user-local state.

### 6. Add Maintenance Guardrails
- Add a lightweight repo policy covering:
  - one root master document
  - runtime residue not tracked by default
  - scripts grouped by purpose
  - tests and tools not mixed into the root casually

## Acceptance Criteria
- The repo root is cleaner and more source-oriented.
- Installers, core app logic, configs, and tests are easier to find.
- Runtime residue no longer competes with real source files.

## Final Deliverable
- short cleanup report with files moved, removed, rewritten, archived, and any unresolved structure decisions

## Archive Instruction
- When done, move this file out of the repo root into an archive/docs-history location.
