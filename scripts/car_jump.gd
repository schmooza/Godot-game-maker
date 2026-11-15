extends Node
var remaining := 0.0
var cooldown := 0.0
var held := false
const DURATION := 0.85
const COOLDOWN := 0.55
func reset() -> void:
	remaining = 0.0
	cooldown = 0.0
	held = false
func tick(delta: float, pressed: bool) -> void:
	remaining = maxf(0.0, remaining - delta)
	cooldown = maxf(0.0, cooldown - delta)
	if pressed and not held and remaining <= 0.0 and cooldown <= 0.0:
		remaining = DURATION
		cooldown = DURATION + COOLDOWN
	held = pressed
func airborne() -> bool:
	return remaining > 0.0
