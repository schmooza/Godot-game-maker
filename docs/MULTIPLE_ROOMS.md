# Multiple rooms (Adventure)

In Edit Scene, find **ROOMS (Adventure)** in Scene & Game Settings. Enter a unique room name (e.g. `Room 2`) and click **Add Room**. Import that room's background, then add and position objects. Use the room dropdown to return to Room 1.

Select a door in Room 1, keep its **On click** action as **Unlock**, set the **Required item** (e.g. `Brass key`), and choose **Destination Room** = `Room 2`. When the player has the item and clicks the door, the item is consumed and Room 2 loads. For transitions that don't require a key, choose **Go To Room** and set the destination.

To end the adventure explicitly, select **Win Game** as an object's action. A legacy Unlock action with no destination still ends the game, preserving older puzzles.

Each room has separate objects, background and scene appearance. Inventory and hit points carry between rooms, and each room remembers its collected/revealed objects. Game Over restarts in Room 1 with full HP and an empty inventory.

Existing single-room saves migrate automatically to Room 1 when loaded. Save the scene after adding rooms. The game engine stores imported room images in Godot's `user://` location, just like existing imported images; transferring the project alone between computers does not automatically transfer those images.
