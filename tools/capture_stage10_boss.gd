# 2026-06-22: Stage10のイントロ各段階と5撃アリーナを画像確認する。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage10"
const BossActionRequestScript := preload("res://scripts/boss/core/BossActionRequest.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed_scene: PackedScene = load("res://stage/Stage10.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	if scene.boss_intro._intro_tween != null:
		scene.boss_intro._intro_tween.kill()
		scene.boss_intro._intro_tween = null
	scene.boss_intro.banner.position.x = 180.0

	scene.boss_intro._show_action("boar_intro_actions_02_dash_launch.png", "DASH")
	await _capture("01_dash_intro")
	scene.boss_intro._show_memory_absorb()
	await _capture("02_memory_absorb")
	scene.boss_intro._show_boss_title()
	await _capture("03_boss_name_hp")
	scene.boss_intro._finish()
	await create_timer(0.25).timeout
	await _capture("04_boss_arena")
	var boss: Node = scene.boss
	boss.set_physics_process(false)
	var dash_warning := BossActionRequestScript.new(&"dash", Vector2.LEFT, &"NATURAL", boss.global_position)
	boss.state_machine.change_state(&"DashTelegraph", dash_warning)
	await _capture("04a_dash_warning_blue")
	var smash_warning := BossActionRequestScript.new(&"smash", Vector2.RIGHT, &"NATURAL", boss.global_position)
	boss.state_machine.change_state(&"SmashTelegraph", smash_warning)
	await _capture("04b_smash_warning_orange")
	boss.sprite.modulate = Color.WHITE
	boss.set_replay_outline_active(true)
	await _capture("04c_replay_outline_purple")
	boss.set_replay_outline_active(false)
	boss.state_machine.change_state(&"Idle", null)
	boss.set_physics_process(true)
	scene.boss_battle._on_initial_trap_resolved(&"falling_rock", false, &"rock_a", {})
	scene.boss_battle._on_initial_trap_resolved(&"timed_drop", false, &"rock_b", {})
	await create_timer(0.12).timeout
	await _capture("05_rock_recovery")
	var rock_a: Node = scene.get_node("Gimmicks/RockA")
	var stopper: Node = scene.get_node("Gimmicks/StopperTrap")
	stopper.lock_with_rock(rock_a)
	await create_timer(0.18).timeout
	await _capture("06_stopper_ready")
	stopper.reset_gimmick()
	scene.get_node("Gimmicks/FinalWall").expose()
	await create_timer(0.18).timeout
	await _capture("07_final_wall_ready")

	print("STAGE10_BOSS_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % file_name))
	assert(image.save_png(path) == OK)
