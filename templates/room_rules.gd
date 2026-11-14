extends RefCounted
## STUDENT EDITABLE ROOM RULES
## Change the room title, object labels, messages, and puzzle rules.
## Keep the three function names and the returned data structure.


func get_room_title() -> String:
	return "The Locked Study"


func get_objects() -> Array:
	return [
		{"id": "desk", "label": "Inspect the desk"},
		{"id": "painting", "label": "Inspect the painting"},
		{"id": "drawer", "label": "Open the drawer"},
		{"id": "door", "label": "Try the locked door"},
	]


func interact(object_id: String, state: Dictionary) -> Dictionary:
	# Return changes to the game state and a message for the player.
	# You can edit this logic to invent your own puzzle.
	match object_id:
		"desk":
			return {"message": "A note says: Look behind the painting."}
		"painting":
			return {"message": "A clue says: The drawer is unlocked."}
		"drawer":
			if state.get("has_key", false):
				return {"message": "The drawer is empty."}
			return {"message": "You found a brass key!", "add_item": "Brass key", "set_flag": "has_key"}
		"door":
			if state.get("has_key", false):
				return {"message": "The door opens. You escaped!", "win": true}
			return {"message": "The door is locked. Find the key."}
	return {"message": "Nothing happens."}
