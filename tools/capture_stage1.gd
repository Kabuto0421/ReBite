# 2026-06-13: Stage1の確認画像を撮る。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage1"
const STAGE_SCENE := "res://stage/Stage1.tscn"

var scene: Node
var player: Node
var skull: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_output_dir()
	_load_stage()

	await _settle_frames(8)
	await _capture("01_initial")

	skull.global_position = Vector2(552, 330)
	skull.velocity = Vector2.ZERO
	skull.commit_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(8)
	await _capture("02_left_memory_tag")

	player.global_position = Vector2(574, 330)
	player.velocity = Vector2.ZERO
	skull.global_position = Vector2(552, 330)
	skull.velocity = Vector2.ZERO
	skull.set_attack_hitbox_active(true)
	await _settle_seconds(0.3)
	await _capture("02b_player_death")
	skull.set_attack_hitbox_active(false)
	await _settle_seconds(0.8)

	skull.global_position = Vector2(640, 330)
	skull.velocity = Vector2.ZERO
	skull.commit_dash_record(Vector2.RIGHT)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(8)
	await _capture("03_right_memory_tag")

	skull.memory_tag.hide_tag()
	skull.global_position = Vector2(1160, 560)
	skull.velocity = Vector2.ZERO
	await _settle_frames(8)
	await _capture("07_stuck_replay_prompt")

	player.global_position = Vector2(610, 330)
	player.facing = -1
	player.sprite.flip_h = true
	player.bite_area.position.x = -34.0
	skull.global_position = Vector2(552, 330)
	skull.velocity = Vector2.ZERO
	skull.commit_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(4)
	player.state_machine.change_state(&"BiteLunge", null)
	await _settle_frames(6)
	await _capture("04_bite_freeze")

	await _settle_seconds(skull.recall_start_delay + 0.18)
	await _capture("05_recalled_dash")

	await _settle_seconds(0.7)
	await _capture("06_after_replay")

	print("STAGE1_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	if scene != null:
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	quit(0)

func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for file_name in DirAccess.get_files_at(absolute_dir):
		if file_name.ends_with(".png"):
			DirAccess.remove_absolute(absolute_dir.path_join(file_name))

func _load_stage() -> void:
	var packed_scene: PackedScene = load(STAGE_SCENE)
	scene = packed_scene.instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	skull = scene.get_node("SkullMonster")

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0

func _capture(name: String) -> void:
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		push_error("Viewport texture is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Viewport image is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % name))
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save capture: %s" % path)
