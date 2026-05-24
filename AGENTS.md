# WTField Project Guide

All contributors, human or AI, should read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR. The Chinese version is available at [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md).

## Project Reality

This repository is a Godot game project.

- Engine: Godot `4.6` with `.NET` enabled
- Primary gameplay code: GDScript
- Main project file: `project.godot`
- Main scene currently points to `scenes/game.tscn`.

## Repository Layout

- `project.godot`: project settings and input map
- `scenes/`: playable scenes such as `game.tscn`, `player.tscn`, and `bullet.tscn`
- `scripts/`: runtime gameplay scripts
- `assets/texture/`: texture art and sprite sheets
- `assets/audio/`: sound effects and music
- `assets/font/`: font assets

## Working Rules

### Godot Asset Hygiene

- Keep `.tscn`, `.gd`, and matching `.uid` files together when adding, moving, or renaming scripts and scenes
- Preserve resource UIDs where possible; do not casually delete and recreate `.uid` files
- Treat `.import` files under `assets/` as project files when they change for a real import-setting reason
- Avoid opening and re-saving unrelated scenes or resources
- Keep scene and resource diffs narrowly scoped to the task

### Generated and Local Files

The current `.gitignore` is intentionally small. Today it ignores:

- `.godot/`
- `android/`
- `.vscode/`

That means contributors must stage carefully and avoid committing local noise or accidental editor churn.

### Code Changes

- Follow existing patterns in the touched subsystem
- Prefer small, behavior-preserving fixes when addressing warnings or refactors
- Keep runtime code in `scripts/` unless a new structure is clearly warranted
- If you change input-driven behavior, verify the related actions in `project.godot`

## Validation

Before calling work complete, use real Godot validation:

1. Open the project in Godot `4.6`
2. Let the editor reimport and parse scripts
3. Check the editor output, debugger, and errors panel for new issues
4. Open the affected scene or resource and verify references are intact
5. Run the relevant scene, or the main scene when practical, and test the touched flow

Do not treat external editor diagnostics alone as sufficient validation.

## Git Expectations

- Keep PRs atomic: one feature, one fix, or one tightly related content change
- Keep commits atomic as well: each commit should contain one coherent feature, fix, or other tightly related change, even if that change touches multiple files
- Use clear commit messages in English
- AI bot or service identities may be used as the git author when preserving AI contribution history is intentional
- If a commit is made by an AI agent, the commit message must include a `Co-authored-by:` trailer for that agent identity
- Do not document workflows, commands, or skills that do not exist in this repository

## Agent-Specific Notes

- Prefer Godot-aware validation when available
- When reading project health, the Godot editor's error output is the source of truth, not only shell tooling
- When a task changes assets, mention whether `.uid` and `.import` files were included intentionally
