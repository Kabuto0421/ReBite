# 2026-06-13: Stage4の確認画像を撮る。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage4"
const STAGE_SCENE := "res://stage/Stage4.tscn"

var scene: Node
var player: Node
var hop: Node
var ride: Node
var hop2: Node
var ride2: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_output_dir()
	_load_stage()
	scene.camera_cinematic = true
	scene.camera.global_position = Vector2(620, 120)
	scene.camera.zoom = Vector2(0.92, 0.92)

	await _settle_frames(8)
	await _capture("01_stage4_layout")

	hop.state_machine.change_state(&"Hop", null)
	await _settle_seconds(0.36)
	await _capture("02_ride_platform_lift")

	await _settle_seconds(0.12)
	player.global_position = ride.global_position + Vector2(ride.size.x * 0.5, 1.0)
	player.velocity = Vector2.ZERO
	await _settle_frames(3)
	player.state_machine.change_state(&"BiteLunge", null)
	await _settle_frames(8)
	await _capture("03_hop_elevator_bite")

	await _settle_seconds(hop.recall_start_delay + 0.20)
	await _capture("04_first_second_lift")

	hop2.state_machine.change_state(&"Hop", null)
	await _settle_seconds(0.36)
	await _capture("05_second_hop_lift")

	await _settle_seconds(0.12)
	player.global_position = ride2.global_position + Vector2(ride2.size.x * 0.5, 1.0)
	player.velocity = Vector2.ZERO
	await _settle_frames(3)
	player.state_machine.change_state(&"BiteLunge", null)
	await _settle_seconds(hop2.recall_start_delay + 0.20)
	await _capture("06_goal_lift")

	await _wait_until_clear(2.0)
	await _capture("07_goal_clear")

	print("STAGE4_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
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
	hop = scene.get_node("HopMonster")
	ride = scene.get_node("RidePlatform")
	hop2 = scene.get_node("HopMonster2")
	ride2 = scene.get_node("RidePlatform2")

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

func _wait_until_clear(timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and not scene.stage_cleared:
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
