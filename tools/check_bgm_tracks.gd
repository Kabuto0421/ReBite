# 2026-06-24: 復元した通常曲とStage10専用曲の形式、切替、ループ設定を確認する。
extends SceneTree

const StageBgmScript := preload("res://scripts/stage/StageBgm.gd")
const REGULAR_PATH := "res://assets/bgm/memory_bite_loop_02.wav"
const INTRO_PATH := "res://assets/bgm/rebite_boar_intro_fanfare.ogg"
const BOSS_PATH := "res://assets/bgm/boar_boss_pressure_theme.ogg"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(load(REGULAR_PATH) is AudioStreamWAV)
	assert(FileAccess.get_file_as_bytes(REGULAR_PATH).size() < 2 * 1024 * 1024)
	for path in [INTRO_PATH, BOSS_PATH]:
		assert(load(path) is AudioStreamOggVorbis)
		assert(FileAccess.get_file_as_bytes(path).size() < 1024 * 1024)

	var regular_bgm: Node = StageBgmScript.new()
	root.add_child(regular_bgm)
	regular_bgm.setup()
	assert(regular_bgm.player != null)
	assert(regular_bgm.player.stream is AudioStreamWAV)
	assert(regular_bgm.player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(absf(regular_bgm.player.stream.get_length() - 13.714) < 0.02)
	regular_bgm.queue_free()
	await process_frame

	var scene: Node = load("res://stage/Stage10.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.stage_bgm.player != null)
	assert(scene.stage_bgm.player.stream is AudioStreamOggVorbis)
	assert(not scene.stage_bgm.player.stream.loop)
	assert(scene.stage_bgm.player.bus == &"Master")
	assert(absf(scene.stage_bgm.player.stream.get_length() - 8.0) < 0.02)
	scene.boss_intro._finish()
	await process_frame
	assert(scene.stage_bgm.player.stream is AudioStreamOggVorbis)
	assert(scene.stage_bgm.player.stream.loop)
	assert(scene.stage_bgm.player.bus == &"BossMusic")
	assert(absf(scene.stage_bgm.player.stream.get_length() - 60.0) < 0.02)
	assert(scene.stage_bgm.player.volume_db == scene.boss_battle_bgm_volume_db)
	scene.stage_bgm.duck()
	assert(scene.stage_bgm.player.volume_db == scene.boss_battle_bgm_volume_db - scene.stage_bgm.duck_db)
	await create_timer(scene.stage_bgm.duck_hold_time + scene.stage_bgm.duck_recover_time + 0.05).timeout
	assert(is_equal_approx(scene.stage_bgm.player.volume_db, scene.boss_battle_bgm_volume_db))

	print("BGM_TRACKS_CHECK_OK")
	scene.queue_free()
	await process_frame
	quit(0)
