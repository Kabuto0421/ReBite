# 2026-06-23: BoarボスSEの実再生、重要音ダッキング、遅延再生を確認する。
extends SceneTree

const AudioSettings := preload("res://scripts/audio/AudioSettings.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	AudioSettings.set_bgm_volume(1.0, false)
	AudioSettings.set_se_volume(1.0, false)
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://stage/Stage10.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var boss_sfx: Node = scene.boss_sfx
	var initial_player_count := _audio_player_count(boss_sfx)

	boss_sfx.play_cue(&"dash")
	assert(_audio_player_count(boss_sfx) == initial_player_count + 1)
	var boss_bgm_volume: float = scene.stage_bgm.active_volume_db
	boss_sfx.play_cue(&"wall_impact")
	assert(_audio_player_count(boss_sfx) == initial_player_count + 2)
	assert(scene.stage_bgm.player.volume_db == boss_bgm_volume - scene.stage_bgm.duck_db)
	boss_sfx.play_cue(&"defeat", boss_sfx.defeat_delay)
	assert(_audio_player_count(boss_sfx) == initial_player_count + 2)
	await create_timer(boss_sfx.defeat_delay + 0.15).timeout
	assert(_audio_player_count(boss_sfx) == initial_player_count + 3)

	print("BOSS_SFX_PLAYBACK_CHECK_OK")
	scene.boss_intro._finish()
	scene.queue_free()
	await process_frame
	AudioServer.set_bus_mute(0, false)
	quit(0)

func _audio_player_count(node: Node) -> int:
	return node.get_children().filter(func(child): return child is AudioStreamPlayer).size()
