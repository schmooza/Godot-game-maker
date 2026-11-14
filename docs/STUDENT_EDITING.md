# Student-editable adventure prototype

1. Run `project.godot` in Godot 4.3+ with F5.
2. Select **Edit Adventure (Student)**.
3. Edit the real GDScript in **Room Rules**: title, objects, messages, and conditions.
4. Click **Play / Test**. Changes are compiled and executed immediately in the student adventure scene.
5. Click **Edit room rules** to return to editing. **Save** writes to `user://student_adventure.gd` (the Windows user's Godot app-data folder). **Reset note** restores the template in the editor; save to keep it.

The earlier Phase 2 escape-room prototype remains available through **Play Adventure (Phase 2)**.

## Boundaries

This is the first working editable component, not the complete Post-it wall. It has one room, one editable code note, and simple button placeholders. Additional rooms, asset import, full project packaging, multiple notes, and other game types remain to be implemented. Student code is executed locally and should only be used with trusted classroom projects; it is not a security sandbox.

## Testing

- [ ] Editor opens from the main screen
- [ ] Changing `get_room_title()` changes the displayed room title
- [ ] Changing an object label changes its button text
- [ ] Changing a clue changes the game message
- [ ] Collecting the key unlocks the door and wins
- [ ] Saving and reopening preserves edits
- [ ] Reset restores the default template
- [ ] Original Phase 2 adventure still works
