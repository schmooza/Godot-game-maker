# Student editor reliability checks

1. Run the project with F5 and select **Edit Adventure (Student)**. The editor should open without the previous `auto_indent_enabled` crash.
2. Edit the room title. Confirm the **Unsaved code changes** label appears.
3. Click **Save**. Confirm **Code saved** appears. Close and reopen the project; the change should persist.
4. Click **Play / Test** and confirm the changed room title appears. Return to the editor and check the code is still present.
5. Import a PNG into the **desk** image slot. Click **Play / Test**; confirm the image appears. Restart the project; it should still appear.
6. Click **Reset image** for desk and confirm the placeholder returns.
7. Enter invalid GDScript and click **Play / Test**; the editor should stay open and show an error message.
8. Restore the original room rules using **Reset note**, then **Save**.

These are manual checks: this build has not been run in Godot in the packaging environment.
