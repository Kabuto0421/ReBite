extends SceneTree

const GateScene := preload("res://props/ReBiteGateRig.tscn")
const MemoryEnemyScript := preload("res://scripts/entities/MemoryEnemy.gd")

func _initialize() -> void:
	var gate := GateScene.instantiate()
	root.add_child(gate)
	await process_frame

	_assert(gate.get_node("Base") is AnimatedSprite2D, "Base must be AnimatedSprite2D.")
	_assert(gate.get_node("Switch") is AnimatedSprite2D, "Switch must be AnimatedSprite2D.")
	_assert(gate.get_node("SwitchHitbox") is Area2D, "SwitchHitbox must be Area2D.")
	_assert(gate.get_node("PulleyBody") is StaticBody2D, "PulleyBody must be StaticBody2D.")
	_assert(gate.get_node("GateBody") is AnimatableBody2D, "GateBody must be AnimatableBody2D.")
	_assert(gate.get_node("GateBody/GateSprite") is Sprite2D, "GateSprite must be Sprite2D.")
	_assert(gate.get_node("GateBody/GateCollision") is CollisionShape2D, "GateCollision must be child of GateBody.")

	var base: AnimatedSprite2D = gate.get_node("Base")
	var switch_sprite: AnimatedSprite2D = gate.get_node("Switch")
	var gate_body: AnimatableBody2D = gate.get_node("GateBody")
	var pulley_body: StaticBody2D = gate.get_node("PulleyBody")
	var switch_hitbox: Area2D = gate.get_node("SwitchHitbox")
	var pulley_collision: CollisionShape2D = gate.get_node("PulleyBody/PulleyCollision")
	var gate_collision: CollisionShape2D = gate.get_node("GateBody/GateCollision")

	_assert(base.sprite_frames.get_frame_count(&"default") == 16, "Base must have 16 effective frames.")
	_assert(switch_sprite.sprite_frames.get_frame_count(&"default") == 4, "Switch must have 4 effective frames.")
	_assert(is_equal_approx(gate.tick_rate, 12.0), "Default tick_rate must be 12 FPS.")
	_assert(gate.switch_enabled, "Switch trigger must be enabled by default.")
	_assert(gate.switch_trigger_group == &"memory_enemy", "Switch trigger group mismatch.")
	_assert(base.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Base must use nearest texture filtering.")
	_assert(switch_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Switch must use nearest texture filtering.")
	_assert((gate.get_node("GateBody/GateSprite") as Sprite2D).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "GateSprite must use nearest texture filtering.")
	_assert(gate_body.sync_to_physics, "GateBody must sync to physics.")
	_assert(pulley_body.position == Vector2(8, -13.5), "PulleyBody position mismatch.")
	_assert(pulley_body.collision_layer == 1, "PulleyBody must block normal platform layer.")
	_assert(pulley_collision.shape.size == Vector2(38, 15), "PulleyCollision shape mismatch.")
	_assert(gate_body.position == Vector2(7, 5), "GateBody must start at tick 0 position.")
	_assert(switch_hitbox.position == Vector2(-4.5, 7.5), "SwitchHitbox position mismatch.")
	_assert((switch_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape.size == Vector2(6, 10), "SwitchHitbox shape mismatch.")
	_assert(gate_collision.shape.size == Vector2(10, 30), "GateCollision shape mismatch.")

	gate_body.sync_to_physics = false
	for tick in gate.TICK_COUNT:
		gate._apply_tick(tick)
		_assert(base.frame == gate.BASE_FRAME_BY_TICK[tick], "Base frame mismatch at tick %d." % tick)
		_assert(switch_sprite.frame == gate.SWITCH_FRAME_BY_TICK[tick], "Switch frame mismatch at tick %d." % tick)
		_assert(gate_body.position == Vector2(7, gate.GATE_BODY_Y_BY_TICK[tick]), "GateBody position mismatch at tick %d." % tick)
	gate._apply_tick(0)
	gate_body.sync_to_physics = true

	var plain_body := CharacterBody2D.new()
	root.add_child(plain_body)
	gate._on_switch_body_entered(plain_body)
	await process_frame
	_assert(not gate.is_running, "Non-memory body must not start the gate cycle.")

	var external_source := Node.new()
	root.add_child(external_source)
	var external_started: bool = gate.activate(external_source)
	_assert(external_started, "External activate(source) must start the gate cycle.")
	_assert(gate.is_running and gate.gate_state == gate.GateState.CYCLING, "External activation must enter cycling state.")
	var rejected_double_start: bool = gate.activate(external_source)
	_assert(not rejected_double_start, "Gate must reject double activation while cycling.")
	await create_timer(1.85).timeout
	_assert(not gate.is_running and gate.gate_state == gate.GateState.CLOSED, "External activation must return to closed state.")

	gate.tick_rate = 24.0
	var fast_started: bool = gate.activate(external_source)
	_assert(fast_started, "Gate must activate after tick_rate change.")
	await create_timer(0.98).timeout
	_assert(not gate.is_running, "Higher tick_rate must shorten the 20 tick cycle.")
	gate.tick_rate = 12.0

	var memory_body := CharacterBody2D.new()
	memory_body.add_to_group(&"memory_enemy")
	root.add_child(memory_body)
	gate._on_switch_body_entered(memory_body)
	await process_frame
	_assert(gate.is_running, "MemoryEnemy group body must start the gate cycle.")
	gate._on_switch_body_entered(memory_body)
	await create_timer(1.85).timeout
	_assert(not gate.is_running, "Gate cycle must finish.")
	_assert(base.frame == 0 and switch_sprite.frame == 0 and gate_body.position == Vector2(7, 5), "Gate cycle must return to tick 0.")

	var enemy := MemoryEnemyScript.new()
	enemy.name = "MemoryEnemyGroupCheck"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	enemy.add_child(sprite)
	var state_machine := Node.new()
	state_machine.name = "StateMachine"
	enemy.add_child(state_machine)
	var memory_tag := Node2D.new()
	memory_tag.name = "MemoryTag"
	enemy.add_child(memory_tag)
	var attack_hitbox := Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	enemy.add_child(attack_hitbox)
	root.add_child(enemy)
	enemy.setup_memory_enemy()
	_assert(enemy.is_in_group(&"memory_enemy"), "MemoryEnemy setup must add memory_enemy group.")

	print("check_rebite_gate_rig: OK")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
