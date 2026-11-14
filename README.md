# The Post-it Note Game Engine — Shared Editor Prototype

Open `project.godot` in Godot 4 and press F5. Choose Adventure, Car Racing or Boss Fight.

All three use the same student-facing scene editor: object selection, image import, background import, positioning, resizing, Save, Play/Test and Reset Scene. Scene layouts are saved in `user://shared_scenes.json` and images in the Godot user data folder. No installation or admin rights required beyond a portable Godot editor; confirm your school's execution policy.

**Adventure:** Drag desk, drawer, painting and door over the background. Test by clicking objects to find the key and open the door. The original editable GDScript rules remain available from **Edit Adventure Code**. Object IDs used by rules must stay the same if you want the existing puzzle logic to work.

**Racing prototype:** Left/Right to steer and avoid an obstacle, complete 3 laps. The scene editor allows background/car/obstacle replacement and placement. This is a simple mechanics prototype, not a full track physics engine.

**Boss prototype:** Arrow keys move, Space shoots. Defeat the boss before losing all lives. Background/player/boss can be replaced and positioned in the shared editor. This is a simple mechanics prototype.

**Known limits:** Additional objects can be placed and imported, but only the original object IDs have prewritten gameplay behaviours. Newly added objects require student GDScript mechanics in a later iteration. The advanced code editor currently applies only to Adventure. This prototype has not been verified by running Godot in this environment.
