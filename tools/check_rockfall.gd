# 2026-06-21: 落石の透過、破壊床解放、坂転動、高速ダメージを確認する。
extends SceneTree

const ROCK_SCENE := "res://props/Rockfall.tscn"
const ROCK_TEXTURE := "res://assets/props/rockfall/rock_36x36.png"

class DamageTarget:
	extends CharacterBody2D
	var killed := false

	func die() -> void:
		killed = true

class ActionPusher:
	extends CharacterBody2D
	var action_record: Resource
	var killed := false

	func current_action_record() -> Resource:
		return action_record

	func die() -> void:
		killed = true

# テスト本体を次フレームから実行する。
func _init() -> void:
	call_deferred("_run")

# 素材と物理ギミックの主要契約を順番に検証する。
func _run() -> void:
	_check_transparent_texture()
	await _check_break_group_release()
	await _check_rotated_slope_roll()
	await _check_memory_action_push_and_break()
	await _check_real_memory_enemy_contacts()
	await _check_pushed_rock_kills_enemy()
	_check_impact_damage()
	print("ROCKFALL_CHECK_OK")
	quit(0)

# PNGが36px角で、実アルファ背景を持つことを確認する。
func _check_transparent_texture() -> void:
	var texture := load(ROCK_TEXTURE) as Texture2D
	assert(texture != null)
	var image := texture.get_image()
	assert(image != null)
	assert(image.get_size() == Vector2i(36, 36))
	assert(image.get_pixel(0, 0).a == 0.0)
	assert(image.get_pixel(18, 18).a > 0.95)

# ActionBreakGroup上で静止し、破壊後に落下することを確認する。
func _check_break_group_release() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var break_group := ActionBreakGroup.new()
	break_group.blocks_enemy = true
	var support := TileRectPart.new()
	support.position = Vector2(0.0, 320.0)
	support.size = Vector2(420.0, 32.0)
	break_group.add_child(support)
	world.add_child(break_group)

	var rock := _instantiate_rock()
	rock.position = Vector2(180.0, 250.0)
	world.add_child(rock)
	await _settle_frames(150)
	assert(break_group.broken.is_connected(rock._on_action_break_group_broken))
	var resting_position: Vector2 = rock.position
	await _settle_frames(30)
	assert(rock.position.distance_to(resting_position) < 1.5)

	break_group._break(null, null)
	await _settle_frames(55)
	assert(rock.position.y > resting_position.y + 100.0)

	root.remove_child(world)
	world.queue_free()
	await process_frame

# 回転したEditableTileGroup上で岩が下り方向へ加速することを確認する。
func _check_rotated_slope_roll() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var slope := EditableTileGroup.new()
	var slope_part := TileRectPart.new()
	slope_part.position = Vector2(0.0, 360.0)
	slope_part.size = Vector2(520.0, 32.0)
	slope_part.rotation = deg_to_rad(22.0)
	slope.add_child(slope_part)
	world.add_child(slope)

	var rock := _instantiate_rock()
	rock.position = Vector2(70.0, 270.0)
	world.add_child(rock)
	var start_x: float = rock.position.x
	await _settle_frames(210)
	assert(rock.position.x > start_x + 100.0)
	assert(absf(rock.rotation) > 0.25)

	root.remove_child(world)
	world.queue_free()
	await process_frame

# DASH/SMASHが最低有効速度を与え、重なり中の破壊床も壊せることを確認する。
func _check_memory_action_push_and_break() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var break_group := ActionBreakGroup.new()
	var wall := TileRectPart.new()
	wall.position = Vector2(100.0, 0.0)
	wall.size = Vector2(32.0, 140.0)
	break_group.add_child(wall)
	world.add_child(break_group)

	var rock := _instantiate_rock()
	rock.gravity_scale = 0.0
	rock.position = Vector2(70.0, 70.0)
	world.add_child(rock)
	var pusher := ActionPusher.new()
	pusher.collision_layer = 4
	world.add_child(pusher)
	await _settle_frames(3)
	assert(not break_group.broken_state)

	var dash_record := ActionRecord.new(&"dash", Vector2.RIGHT, Vector2(260.0, 0.0), 0.34)
	pusher.action_record = dash_record
	assert(rock._try_apply_memory_action_push(pusher))
	assert(rock.linear_velocity.x >= rock.minimum_action_push_speed)
	assert(rock.current_action_record().action_name == &"rockfall")
	assert(rock.can_break_action_group(break_group))
	assert(not rock._try_apply_memory_action_push(pusher))
	var reverse_pusher := ActionPusher.new()
	reverse_pusher.collision_layer = 4
	reverse_pusher.action_record = ActionRecord.new(&"dash", Vector2.LEFT, Vector2(-260.0, 0.0), 0.34)
	world.add_child(reverse_pusher)
	var rolling_velocity := rock.linear_velocity
	assert(not rock._try_apply_memory_action_push(reverse_pusher))
	assert(rock.linear_velocity == rolling_velocity)
	await _settle_frames(3)
	assert(break_group.broken_state)

	rock.reset_to_spawn()
	var smash_record := ActionRecord.new(&"smash", Vector2.LEFT, Vector2(-118.0, 0.0), 1.2)
	pusher.action_record = smash_record
	assert(rock._try_apply_memory_action_push(pusher))
	assert(rock.linear_velocity.x <= -rock.minimum_action_push_speed)
	rock._recent_peak_speed = rock.kill_speed + 100.0
	rock._on_body_entered(pusher)
	assert(not pusher.killed)

	rock.reset_to_spawn()
	pusher.action_record = ActionRecord.new(&"jump", Vector2.UP, Vector2(0.0, -330.0), 0.42)
	assert(not rock._try_apply_memory_action_push(pusher))
	rock.linear_velocity = Vector2(rock.action_break_speed + 20.0, 0.0)
	rock.motion_state = Rockfall.MotionState.ROLLING
	assert(rock.can_break_action_group())
	assert(rock.current_action_record().action_name == &"rockfall")
	break_group.reset_group()
	break_group._on_break_area_body_entered(rock)
	assert(break_group.broken_state)

	root.remove_child(world)
	world.queue_free()
	await process_frame

# 実際のSkullMonsterとBoarMonsterの接触で岩が押されることを確認する。
func _check_real_memory_enemy_contacts() -> void:
	await _check_enemy_contact_push("res://entities/SkullMonster.tscn", &"Dash", 28)
	await _check_enemy_contact_push("res://entities/boar_monster.tscn", &"Smash", 58)

# 指定MemoryEnemyの行動状態を開始し、左側の岩が押されることを確認する。
func _check_enemy_contact_push(scene_path: String, action_state: StringName, frame_count: int) -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor := EditableTileGroup.new()
	var floor_part := TileRectPart.new()
	floor_part.position = Vector2(0.0, 400.0)
	floor_part.size = Vector2(640.0, 32.0)
	floor.add_child(floor_part)
	world.add_child(floor)

	var rock := _instantiate_rock()
	rock.position = Vector2(230.0, 377.0)
	world.add_child(rock)
	var enemy_scene: PackedScene = load(scene_path)
	var enemy = enemy_scene.instantiate()
	enemy.position = Vector2(305.0, 400.0)
	world.add_child(enemy)
	await _settle_frames(3)
	var start_x: float = rock.position.x
	enemy.state_machine.change_state(action_state, enemy.last_record)
	await _settle_frames(frame_count)
	assert(rock.position.x < start_x - 12.0)
	assert(rock.current_action_record() != null)
	assert(enemy.current_state_name() != &"Dying")

	root.remove_child(world)
	world.queue_free()
	await process_frame

# SkullMonsterのDASHで押された岩が別の敵を倒すことを確認する。
func _check_pushed_rock_kills_enemy() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor := EditableTileGroup.new()
	var floor_part := TileRectPart.new()
	floor_part.position = Vector2(0.0, 400.0)
	floor_part.size = Vector2(720.0, 32.0)
	floor.add_child(floor_part)
	world.add_child(floor)

	var rock := _instantiate_rock()
	rock.position = Vector2(390.0, 377.0)
	world.add_child(rock)
	var skull_scene: PackedScene = load("res://entities/SkullMonster.tscn")
	var target = skull_scene.instantiate()
	target.position = Vector2(270.0, 400.0)
	world.add_child(target)
	var pusher = skull_scene.instantiate()
	pusher.position = Vector2(480.0, 400.0)
	world.add_child(pusher)
	await _settle_frames(3)
	target.prepare_dash_record(Vector2.RIGHT)
	target.state_machine.change_state(&"Dash", target.last_record)
	target.set_physics_process(false)
	pusher.state_machine.change_state(&"Dash", pusher.last_record)
	await _settle_frames(26)
	assert(target.current_state_name() == &"Dying")
	assert(pusher.current_state_name() != &"Dying")

	root.remove_child(world)
	world.queue_free()
	await process_frame

# 高速時だけPlayer・敵レイヤーのdieを呼ぶことを確認する。
func _check_impact_damage() -> void:
	var rock := _instantiate_rock()
	root.add_child(rock)
	var fast_target := DamageTarget.new()
	fast_target.collision_layer = 2
	root.add_child(fast_target)
	rock._recent_peak_speed = rock.kill_speed + 1.0
	rock._on_body_entered(fast_target)
	assert(fast_target.killed)

	var slow_target := DamageTarget.new()
	slow_target.collision_layer = 4
	root.add_child(slow_target)
	rock._recent_peak_speed = rock.kill_speed - 1.0
	rock.linear_velocity = Vector2.ZERO
	rock._on_body_entered(slow_target)
	assert(not slow_target.killed)

	root.remove_child(rock)
	rock.queue_free()
	root.remove_child(fast_target)
	fast_target.queue_free()
	root.remove_child(slow_target)
	slow_target.queue_free()

# 落石シーンを生成する。
func _instantiate_rock() -> Rockfall:
	var packed_scene: PackedScene = load(ROCK_SCENE)
	assert(packed_scene != null)
	var rock := packed_scene.instantiate() as Rockfall
	assert(rock != null)
	return rock

# 指定フレーム数だけ描画と物理を進める。
func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
