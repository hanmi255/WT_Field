# Contributing Guide

> Chinese version: [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md)

## Before You Start

This repository is a Godot project.

Current baseline:

- Godot `4.6`
- `.NET` enabled
- Main scene: `scenes/game.tscn`
- Runtime code in `scripts/`

Most contributions here fall into one of these categories:

- gameplay scripts in `scripts/`
- scene updates in `scenes/`
- art, audio, and font assets in `assets/`
- project configuration in `project.godot`

## Repository Layout

- `project.godot`: project configuration, renderer setup, input actions, and startup scene
- `scenes/`: playable scenes and scene composition
- `scripts/`: GDScript runtime logic
- `assets/texture/`: textures and sprite sheets
- `assets/audio/`: music and sound effects
- `assets/font/`: font assets

## Rule 1: Keep Changes Atomic

Each commit or PR should contain one coherent change.

Good examples:

- one gameplay bug fix
- one movement or animation adjustment
- one scene wiring fix
- one asset import-setting correction
- one input-map update for a specific feature

Do not combine unrelated scene edits, configuration churn, and gameplay changes in one commit unless they are required for the same feature to work.

## Rule 2: Commit Godot Assets Correctly

Godot projects rely on stable scene paths, resource references, and UIDs.

- Commit `.uid` files together with the scripts or scenes they belong to
- Do not casually delete and regenerate `.uid` files
- If you rename or move a scene or script, make sure dependent references still resolve
- Commit `.import` files when import settings changed intentionally
- If an asset only changed because the editor reimported it without a meaningful project change, inspect carefully before staging

Repository-local ignore rules currently exclude:

- `.godot/`
- `android/`
- `.vscode/`

That means many local or accidental edits remain visible to Git unless you stage selectively.

## Rule 3: Be Careful With Project Configuration

Treat `project.godot` as a high-signal file.

- Keep input-map edits intentional and review them closely
- Avoid unrelated renderer, window, or physics changes
- If you change the startup scene, explain why
- Do not hand-edit configuration casually when the Godot editor can make the change safely

## Rule 4: Follow Existing Code Patterns

- Follow the style already present in the touched scripts
- Prefer clear GDScript over unnecessary abstraction
- Keep fixes small when addressing warnings or cleanup
- Add comments only when they save real reader effort

## Validation

Before claiming work is complete, run the real checks for a Godot project:

1. Open the project in Godot `4.6`
2. Let the editor import assets and parse scripts successfully
3. Check the errors panel, debugger, and output for new problems
4. Open the affected scene, script, or asset and verify references were not broken
5. Run the relevant scene, or the main scene when practical, and test the touched behavior

Useful local validation targets:

- a clean project load with no new script parse errors
- running `scenes/game.tscn` when the change affects gameplay
- opening the touched scene to confirm node paths and exported references
- verifying movement, animation, collision, or projectile behavior directly in the editor runtime

Do not rely on external editor linting alone as proof that the project is healthy.

## Scene, Script, and Asset Changes

- Keep `.tscn` diffs narrow; avoid opening and saving unrelated scenes
- Preserve node paths and exported references when reorganizing scenes
- If you change a shared asset import setting, verify the visual or audio result in the affected scene
- When changing scripts referenced by scenes, verify the scene still instantiates and runs correctly

## Commit Messages

Use clear English commit messages. A format such as `<type>: <subject>` is preferred.

Examples:

- `fix: prevent bullet from surviving wall collisions`
- `fix: keep player facing animation in sync`
- `feat: add bullet scene setup`
- `refactor: simplify player movement animation update`

Keep commits atomic and stage files selectively. `git add .` is usually the wrong choice for this repository.

AI-assisted commits are allowed and encouraged to preserve contribution history when that matches your workflow.

- If you want AI contributors such as Claude or Codex to appear in Git history or GitHub contributor attribution, use the corresponding bot or service identity as the git author
- If a commit is authored by an AI agent, the commit message must include a `Co-authored-by:` trailer for that same agent identity
- A plain `claude` or `codex` mention in the commit subject alone usually does not make that identity appear in GitHub Contributors
- If you use an AI identity, make sure the author name and email are intentionally configured for that identity before committing

Example trailer:

```text
Co-authored-by: Codex <codex@example.com>
```
