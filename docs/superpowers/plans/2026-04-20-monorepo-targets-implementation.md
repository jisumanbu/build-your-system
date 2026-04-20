# Monorepo Targets Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `build-your-system` into a single-source monorepo that includes the Codex target under `targets/codex/build-your-system-assistant`.

**Architecture:** Keep the existing Claude-facing plugin layout intact at the repo root, add a Codex-specific target subtree, and update root documentation to describe the repository as a multi-host monorepo. This migration is intentionally a structural move, not a shared-core refactor.

**Tech Stack:** Markdown plugin manifests, Python helper scripts, shell install conventions, git repo restructuring

---

### Task 1: Create Migration Docs In The Monorepo

**Files:**
- Create: `docs/superpowers/specs/2026-04-20-monorepo-targets-design.md`
- Create: `docs/superpowers/plans/2026-04-20-monorepo-targets-implementation.md`

- [ ] **Step 1: Write the design doc**

Describe why dual-repo maintenance is being replaced with a single-source monorepo and define the target directory structure.

- [ ] **Step 2: Write the implementation plan**

Document the structural migration, documentation updates, and verification steps with exact paths.

- [ ] **Step 3: Verify the docs exist**

Run: `find docs/superpowers -maxdepth 3 -type f | sort`
Expected: both new markdown files appear.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-04-20-monorepo-targets-design.md docs/superpowers/plans/2026-04-20-monorepo-targets-implementation.md
git commit -m "docs: add monorepo migration design and plan"
```

### Task 2: Move Codex Target Into The Monorepo

**Files:**
- Create: `targets/codex/build-your-system-assistant/**`
- Source reference: `/Users/jliu/Projects/build-your-system-codex/**`

- [ ] **Step 1: Create the target parent directories**

Run: `mkdir -p targets/codex`
Expected: `targets/codex` exists.

- [ ] **Step 2: Copy the existing Codex target into the monorepo**

Run: `cp -R /Users/jliu/Projects/build-your-system-codex targets/codex/build-your-system-assistant`
Expected: the Codex manifest, commands, skills, scripts, docs, and tests appear under the new target path.

- [ ] **Step 3: Remove runtime-only cache artifacts if present**

Run: `find targets/codex/build-your-system-assistant -type d -name '__pycache__' -prune -exec rm -rf {} +`
Expected: no `__pycache__` directories remain.

- [ ] **Step 4: Verify the moved target structure**

Run: `find targets/codex/build-your-system-assistant -maxdepth 2 -type f | sort | sed -n '1,200p'`
Expected: `.codex-plugin/plugin.json`, `commands/`, `skills/`, `scripts/`, `tests/`, and docs files are present.

- [ ] **Step 5: Commit**

```bash
git add targets/codex/build-your-system-assistant
git commit -m "feat: add codex target to monorepo"
```

### Task 3: Update Repository Documentation For Multi-Host Layout

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Optionally modify: `assistant/CONTRIBUTING.md`

- [ ] **Step 1: Rewrite the root README**

Explain that the repo now contains multiple host targets: Claude targets at the root and the Codex target under `targets/codex/build-your-system-assistant`.

- [ ] **Step 2: Update installation sections**

Add separate install/update guidance for:
- Claude marketplace / clone usage
- Codex local plugin usage from the monorepo target path

- [ ] **Step 3: Update contributor guidance**

Adjust `CLAUDE.md` to reflect the monorepo structure so future edits land in the correct target.

- [ ] **Step 4: Verify documentation references**

Run: `rg -n "build-your-system-codex|targets/codex|monorepo|Codex" README.md CLAUDE.md assistant/CONTRIBUTING.md`
Expected: root docs point to the monorepo target rather than the standalone Codex repo.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md assistant/CONTRIBUTING.md
git commit -m "docs: describe multi-target monorepo layout"
```

### Task 4: Verify Codex Target Still Works In-Repo

**Files:**
- Test: `targets/codex/build-your-system-assistant/tests/test_analyze_codex_activity.py`

- [ ] **Step 1: Run the Codex target tests**

Run: `cd targets/codex/build-your-system-assistant && python3 -m unittest discover -s tests -p 'test_*.py' -v`
Expected: existing Codex tests pass.

- [ ] **Step 2: Inspect git status**

Run: `git status --short`
Expected: clean working tree after commits.

- [ ] **Step 3: Capture final structure for review**

Run: `find . -maxdepth 3 -type d | sort | sed -n '1,200p'`
Expected: repo root still contains Claude targets, and `targets/codex/build-your-system-assistant` exists.

- [ ] **Step 4: Commit any final touch-ups**

```bash
git add -A
git commit -m "chore: finalize monorepo target migration"
```
