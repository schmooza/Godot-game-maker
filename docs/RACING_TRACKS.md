# Student-designed racing tracks

Open **2D Car Racing** from the Games menu. Draw one continuous closed black line on a white background in Paint, save as a PNG, and click **Import black-line track**. The imported black line becomes the centreline of a grey road. Choose road width and number of laps, then click Play / Test. Use arrow keys or WASD (if mapped to Godot UI actions) to drive. The car stops at the edge of the generated road.

The racing panel displays lap progress, current lap time, fastest lap and the ten fastest completed race times saved locally on this computer. Track images and settings are stored in Godot user data, so changing computers requires copying user data. The finish is the leftmost track point; checkpoints are automatically placed around the track's bounds. Clean, simple circuits work best. This first implementation does not guarantee accurate lap detection for unusual self-crossing or irregular tracks; validate each track before student competition.

This is a separate Racing editor. Adventure and Boss game files are preserved.
