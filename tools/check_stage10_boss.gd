# 2026-06-22: Stage10の5撃ルート、再演制約、失敗復旧を自動確認する。
extends SceneTree

const BossActionRequestScript := preload("res://scripts/boss/core/BossActionRequest.gd")
const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage10.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var boss: Node = scene.get_node("BoarBoss")
	var battle: Node = scene.boss_battle
	var boss_sfx: Node = scene.boss_sfx
	var boss_camera_feedback: Node = scene.boss_camera_feedback
	var boss_impact_feedback: Node = scene.boss_impact_feedback
	var rock_a: Node = scene.get_node("Gimmicks/RockA")
	var rock_b: Node = scene.get_node("Gimmicks/RockB")
	assert(battle.get_script().get_base_script().resource_path.ends_with("BossBattleBase.gd"))
	assert(boss_sfx.get_script().get_base_script().resource_path.ends_with("BossBattleSfx.gd"))
	assert(boss_sfx.cue_streams.size() == 8)
	assert(boss.action_started.is_connected(boss_sfx._on_action_started))
	assert(scene.get_node("Gimmicks/FallingRockTrap").fall_started.is_connected(boss_sfx._on_fall_started))
	assert(scene.get_node("Gimmicks/TimedDropTrap").fall_started.is_connected(boss_sfx._on_fall_started))
	assert(scene.get_node("Gimmicks/FallingRockTrap").landing_contact.is_connected(boss_sfx._on_landing_contact))
	assert(scene.get_node("Gimmicks/FinalWall").wall_contact.is_connected(boss_sfx._on_wall_contact))
	assert(boss.smash_impact_started.is_connected(boss_camera_feedback._on_smash_impact_started))
	assert(rock_a.smash_contacted.is_connected(boss_impact_feedback._on_rock_smash_contacted))
	assert(scene.get_node("Gimmicks/FallingRockTrap").landing_contact.is_connected(boss_impact_feedback._on_landing_contact))
	for cue_id in [&"dash", &"smash", &"damage", &"defeat", &"wall_impact", &"falling_warning", &"falling_combined", &"falling_impact"]:
		assert(boss_sfx.cue_streams[cue_id] is AudioStreamWAV)
	var final_wall: Node = scene.get_node("Gimmicks/FinalWall")
	var final_wall_shape: CollisionShape2D = final_wall.get_node("CollisionShape2D")
	assert(scene.boss == boss)
	assert(scene.bgm_path.ends_with("memory_bite_loop_02.wav"))
	assert(not scene.bgm_autoplay)
	assert(scene.boss_intro_bgm_path.ends_with("rebite_boar_intro_fanfare.ogg"))
	assert(scene.boss_battle_bgm_path.ends_with("boar_boss_pressure_theme.ogg"))
	assert(scene.boss_music_bus != null)
	assert(scene.boss_intro_duration_scale == 2.05)
	assert(load(scene.boss_intro_bgm_path) is AudioStreamOggVorbis)
	assert(load(scene.boss_battle_bgm_path) is AudioStreamOggVorbis)
	assert(boss.max_hp == 5)
	assert(boss.current_hp == 5)
	boss.play_animation(&"idle")
	assert(boss.sprite.position.y == boss.idle_sprite_y)
	boss.play_animation(&"walk")
	assert(boss.sprite.position.y == boss.walk_sprite_y)
	boss.play_animation(&"smash")
	assert(boss.sprite.position.y == boss.smash_sprite_y)
	boss.play_animation(&"idle")
	assert(battle.current_phase() == &"Intro")
	assert(paused)
	assert(scene.boss_intro.title_label.text == "BOSS_BOAR")
	assert(scene.boss_intro.hp_label.text == "HP  ■ ■ ■ ■ ■")
	assert(scene.boss_intro.boss_portrait.sprite_frames == boss.sprite.sprite_frames)
	scene.boss_intro._show_memory_absorb()
	assert(scene.boss_intro.boss_portrait.visible)
	assert(scene.boss_intro.boss_portrait.position == Vector2(460, 154))
	scene.boss_intro._show_boss_title()
	assert(scene.boss_intro.boss_portrait.visible)
	assert(scene.boss_intro.boss_portrait.position == Vector2(235, 154))
	assert(scene.boss_intro._duration_scale == scene.boss_intro_duration_scale)
	assert(final_wall_shape.position.x == 40.0)
	assert((final_wall_shape.shape as RectangleShape2D).size.x == 28.0)
	assert(scene.stage_hud.objective_label.text == "目標：ボスを倒す (0/5)")
	assert(scene.camera_mode == scene.Stage10CameraMode.ARENA)

	# Telegraph時に固定した方向はPlayer移動後も変わらず、再演は記憶を上書きしない。
	var natural := BossActionRequestScript.new(&"dash", Vector2.LEFT, &"NATURAL", boss.global_position)
	var requested_cues: Array[StringName] = []
	boss_sfx.cue_requested.connect(func(cue_id: StringName, _delay: float): requested_cues.append(cue_id))
	boss_sfx._on_action_started(natural)
	boss.begin_telegraph(natural)
	assert(boss.attack_hitbox.position.x == -boss.dash_hitbox_offset_x)
	boss.state_machine.change_state(&"DashTelegraph", natural)
	assert(boss.sprite.modulate.is_equal_approx(Color(0.62, 0.78, 1.0)))
	var outline_shader_code: String = (boss.sprite.material as ShaderMaterial).shader.code
	assert(outline_shader_code.contains("varying vec4 canvas_modulate"))
	assert(outline_shader_code.contains("canvas_modulate = COLOR"))
	var natural_smash := BossActionRequestScript.new(&"smash", Vector2.RIGHT, &"NATURAL", boss.global_position)
	boss.state_machine.change_state(&"SmashTelegraph", natural_smash)
	assert(boss.sprite.modulate.is_equal_approx(Color(1.0, 0.72, 0.34)))
	boss.state_machine.change_state(&"DashTelegraph", natural)
	var stored_record: Resource = boss.last_record
	assert(stored_record.action_name == &"dash")
	assert(stored_record.direction == Vector2.LEFT)
	var replay := BossActionRequestScript.new(&"smash", Vector2.RIGHT, &"REBITE_REPLAY", boss.global_position)
	boss_sfx._on_action_started(replay)
	boss_sfx._on_environment_damage_applied({}, 4, 5)
	boss_sfx._on_fall_started()
	boss_sfx._on_landing_contact(null, Vector2.ZERO, false)
	boss_sfx._on_wall_contact(null, {}, Vector2.ZERO)
	boss_sfx._on_boss_defeated()
	assert(requested_cues == [&"dash", &"smash", &"damage", &"falling_warning", &"falling_impact", &"wall_impact", &"defeat"])
	boss.begin_telegraph(replay)
	assert(boss.attack_hitbox.position.x == boss.smash_hitbox_offset_x)
	boss.state_machine.change_state(&"SmashTelegraph", replay)
	assert(boss.sprite.modulate.is_equal_approx(Color.WHITE))
	assert(((boss.sprite.material as ShaderMaterial).get_shader_parameter("tint_color") as Color).is_equal_approx(Color.WHITE))
	assert(boss.shockwave_area.position.x == boss.smash_shockwave_hitbox_offset_x)
	assert(boss.shockwave_sprite.position.x == boss.smash_shockwave_visual_offset_x)
	var replay_dash := BossActionRequestScript.new(&"dash", Vector2.LEFT, &"REBITE_REPLAY", boss.global_position)
	boss.state_machine.change_state(&"DashTelegraph", replay_dash)
	assert(boss.sprite.modulate.is_equal_approx(Color.WHITE))
	assert(boss.last_record == stored_record)
	assert(boss.last_record.direction == Vector2.LEFT)

	scene.boss_intro._finish()
	await _settle_frames(2)
	assert(not paused)
	var shake_requests: Array[Vector2] = []
	boss_camera_feedback.shake_requested.connect(func(strength: float, duration: float): shake_requests.append(Vector2(strength, duration)))
	boss.notify_smash_impact_started(replay)
	assert(shake_requests == [Vector2(6.0, 0.10)])
	var boss_music_bus_index := AudioServer.get_bus_index(&"BossMusic")
	assert(boss_music_bus_index >= 0)
	assert(AudioServer.get_bus_effect(boss_music_bus_index, 0) is AudioEffectEQ10)
	assert(scene.stage_bgm.bus_name == &"BossMusic")
	var boss_equalizer := AudioServer.get_bus_effect(boss_music_bus_index, 0) as AudioEffectEQ10
	assert(boss_equalizer.get_band_gain_db(6) == 7.0)
	assert(battle.current_phase() == &"TeachSmash")
	assert(scene.camera.zoom == scene.arena_camera_zoom)
	assert(scene.camera.global_position == scene.arena_camera_position)
	var falling_trap: Node = scene.get_node("Gimmicks/FallingRockTrap")
	var timed_trap: Node = scene.get_node("Gimmicks/TimedDropTrap")
	var stopper: Node = scene.get_node("Gimmicks/StopperTrap")
	var directionless_falling_trap: Node = load("res://boss/gimmicks/FallingRockTrap.tscn").instantiate()
	root.add_child(directionless_falling_trap)
	await process_frame
	directionless_falling_trap.arm(boss)
	var natural_right_smash := ActionRecordScript.new(&"smash", Vector2.RIGHT, Vector2.ZERO, 0.2, &"NATURAL")
	assert(not directionless_falling_trap.receive_memory_action_push(boss, natural_right_smash))
	var replay_right_smash := ActionRecordScript.new(&"smash", Vector2.RIGHT, Vector2.ZERO, 0.2, &"REBITE_REPLAY")
	assert(directionless_falling_trap.receive_memory_action_push(boss, replay_right_smash))
	directionless_falling_trap.queue_free()
	assert(falling_trap.attention_pulse.active)
	assert(not timed_trap.attention_pulse.active)
	assert(not rock_a.attention_pulse.active)
	assert(not rock_b.attention_pulse.active)
	assert(not stopper.attention_pulse.active)
	assert(not final_wall.attention_pulse.active)
	var camera_toggle := InputEventKey.new()
	camera_toggle.keycode = KEY_C
	camera_toggle.pressed = true
	scene._unhandled_input(camera_toggle)
	await _settle_frames(1)
	assert(scene.camera_mode == scene.Stage10CameraMode.PLAYER_FOLLOW)
	assert(scene.camera.zoom == scene.player_camera_zoom)
	boss.set_physics_process(false)

	# 自然攻撃由来イベントはHPを減らさない。
	assert(not battle.damage_resolver.request_damage({
		"event_id": "natural_rejected",
		"source": &"NATURAL",
		"damage": 1,
	}))
	assert(boss.current_hp == 5)

	# 初回2罠を両方外しても、再利用岩は合計4回分残る。
	battle._on_initial_trap_resolved(&"falling_rock", false, &"rock_a", {})
	assert(battle.current_phase() == &"TeachDash")
	assert(not falling_trap.attention_pulse.active)
	assert(timed_trap.attention_pulse.active)
	var position_before_marker: Vector2 = boss.global_position
	boss.global_position.x = timed_trap.marker_sprite.global_position.x
	boss.set_active_action_record(ActionRecordScript.new(&"dash", Vector2.RIGHT, Vector2.RIGHT * boss.dash_speed, boss.dash_duration, &"REBITE_REPLAY"))
	timed_trap._process(0.0)
	boss.clear_active_action_record()
	assert(timed_trap.replay_dash_entered_marker)
	boss.global_position = position_before_marker
	battle._on_initial_trap_resolved(&"timed_drop", false, &"rock_b", {})
	assert(battle.current_phase() == &"RockRecovery")
	assert(not timed_trap.attention_pulse.active)
	assert(rock_a.attention_pulse.active)
	assert(rock_b.attention_pulse.active)
	assert(not stopper.attention_pulse.active)
	assert(stopper.socket_sprite.texture.resource_path.ends_with("rock_socket_00.png"))
	assert(stopper.socket_glow.visible)
	stopper.lock_with_rock(rock_a)
	assert(paused)
	assert(boss_impact_feedback.holding)
	assert(stopper.socket_sprite.texture.resource_path.ends_with("rock_socket_01.png"))
	assert(not stopper.socket_glow.visible)
	assert(not rock_a.attention_pulse.active)
	assert(not rock_b.attention_pulse.active)
	assert(stopper.attention_pulse.active)
	await _settle_frames(6)
	assert(not paused)
	assert(not boss_impact_feedback.holding)
	stopper.reset_gimmick()
	stopper.activate()
	assert(rock_a.uses_remaining + rock_b.uses_remaining == 4)
	assert(not final_wall.active)

	# Player死亡と復帰を挟んでもBoss戦の進行状態を維持する。
	var phase_before_death: StringName = battle.current_phase()
	var hp_before_death: int = boss.current_hp
	var uses_before_death: int = rock_a.uses_remaining + rock_b.uses_remaining
	scene.player.die()
	await _settle_frames(70)
	assert(not scene.player.is_dead)
	assert(battle.current_phase() == phase_before_death)
	assert(boss.current_hp == hp_before_death)
	assert(rock_a.uses_remaining + rock_b.uses_remaining == uses_before_death)

	# 4つの岩使用と4ダメージを同期させ、残り1でだけ最終壁を解禁する。
	var rocks := [rock_a, rock_a, rock_b, rock_b]
	for i in rocks.size():
		var rock: Node = rocks[i]
		rock.consume_use()
		assert(battle.damage_resolver.request_damage({
			"event_id": "rock_damage_%d" % i,
			"source": &"REBITE_REPLAY",
			"damage": 1,
		}))
		assert(boss.current_hp == 4 - i)
		assert(final_wall.active == (i == 3))
	assert(rock_a.uses_remaining == 0)
	assert(rock_b.uses_remaining == 0)
	assert(battle.current_phase() == &"FinalCharge")
	assert(not rock_a.attention_pulse.active)
	assert(not rock_b.attention_pulse.active)
	assert(final_wall.attention_pulse.active)

	# 最終壁の1撃だけでHP0となる。
	assert(battle.damage_resolver.request_damage({
		"event_id": "final_wall_damage",
		"source": &"REBITE_REPLAY",
		"damage": 1,
	}))
	assert(boss.current_hp == 0)
	assert(battle.current_phase() == &"Clear")
	assert(scene.stage_hud.objective_label.text.contains("(5/5)"))

	print("STAGE10_BOSS_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
