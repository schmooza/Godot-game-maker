# Phase 1 — Portable Godot Foundation

This phase establishes an install-free Godot 4 project with a student-facing window and a simple selector for the three planned game boards. It does **not** implement the games or the final Post-it interface.

## Run in a school lab

1. Open the project folder in a portable Godot 4 editor (4.3 or newer).
2. Select **Run Project (F5)**.
3. Students interact with the custom app window, not the editor tools.

No external Python runtime, plugins, or administrator installation is required. School execution policies still apply.

## Scope

- Point-and-Click Adventure
- 2D Racing
- Bullet Hell Boss Fight

The next phases will build three working games before exposing guided, editable GDScript Post-it notes.

## Phase 1 acceptance checks

- [ ] Godot imports the project without errors.
- [ ] F5 opens the student-facing application.
- [ ] All three board choices are selectable.
- [ ] Project runs from a portable folder without installing dependencies.
- [ ] Test on a school Windows machine.

The checkboxes remain unchecked until verified in Godot on the target machines.
