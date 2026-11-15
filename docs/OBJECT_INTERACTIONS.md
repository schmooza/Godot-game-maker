# Object interactions (Adventure)

In the shared editor, select an object and choose **On click**:

- **Inspect**: show its message.
- **Swap**: switch immediately to an optional `<object_id>_open.png` image. No animation.
- **Reveal**: reveal another object by its **Target object ID**. The target must be marked **Hidden until revealed**.
- **Collect**: hide the object and add **Inventory item** to the inventory.
- **Unlock**: finish the game if **Required item** is in the inventory.

Example: the default drawer reveals the hidden `key` object. Click the key to collect **Brass key**, then click the door to escape.

For a custom open-state image, import it using the object's ID with `_open` appended as its image slot. For example `painting_open`. You can also put a PNG at `assets/placeholders/painting_open.png`.

All interactions are instant. No animations. The car and boss games keep their existing controls.

**Note:** The advanced Adventure GDScript editor is retained separately. The shared scene editor uses these simple interaction properties during Play / Test.
