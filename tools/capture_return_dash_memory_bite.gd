# 2026-06-24: 逆向きDASH中のタグ保持、即時上書き、再演をStage1で画像確認する。
extends SceneTree

const OUTPUT_DIR := "res://artifacts/return_dash_memory_bite"

# SceneTree起動後にStage1を開く。
func _init() -> void:
	call_deferred("_run")

# 実ゲームSceneで戻り、割り込み、再演準備を撮影する。
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	change_scene_to_file("res://stage/Stage1.tscn")
	await process_frame
	await physics_frame
	var stage: Node = current_scene
	stage.stage_hud.briefing_overlay.visible = false
	stage.stage_hud.stage_info_label.modulate.a = 1.0
	stage.stage_hud.objective_label.modulate.a = 1.0
	var player: Node = stage.player
	var skull: Node = stage.skull
	player.global_position = Vector2(980.0, 575.0)
	skull.global_position = Vector2(875.0, 575.0)
	player.facing = -1
	player.sprite.flip_h = true
	player.bite_area.position.x = -34.0
	skull.commit_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"RightDash", null)
	await process_frame
	await physics_frame
	await _capture("01_return_with_tag.png")

	var bite_context: Dictionary = player.prepare_bite_context()
	player.state_machine.change_state(&"BiteWindup", bite_context)
	await process_frame
	await _capture("02_bite_breaking.png")

	await _settle_seconds(0.07)
	await _capture("03_arrow_injection.png")

	await _settle_seconds(0.17)
	await _capture("04_memory_injected.png")

	await _settle_seconds(skull.recall_start_delay - 0.24 + 0.03)
	await _capture("05_replay_launch.png")
	print("RETURN_DASH_MEMORY_BITE_CAPTURE_OK")
	quit(0)

# 現在のViewportをPNGへ保存する。
func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	assert(error == OK)

# 60fps換算で指定時間分のフレームを進める。
func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
