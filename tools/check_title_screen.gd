# 2026-07-06: タイトル画面のロゴ、ボタン、設定パネル構造を確認する。
extends SceneTree

const AudioSettings := preload("res://scripts/audio/AudioSettings.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/TitleScreen.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	assert(scene.menu_buttons.size() == 2)
	assert(scene.title_bgm_path.ends_with("rebite_title_bass_clean_ending.wav"))
	assert(scene.title_music_bus_name == &"TitleMusic")
	assert(scene.title_music_bus != null)
	assert(scene.stage_bgm.bgm_path.ends_with("rebite_title_bass_clean_ending.wav"))
	assert(scene.stage_bgm.bus_name == &"TitleMusic")
	assert(scene.SETTINGS_TEXT_TEXTURE_PATH.ends_with("title_text_options.png"))
	var title_music_bus_index := AudioServer.get_bus_index(&"TitleMusic")
	assert(title_music_bus_index >= 0)
	assert(AudioServer.get_bus_effect(title_music_bus_index, 0) is AudioEffectEQ10)
	var title_equalizer := AudioServer.get_bus_effect(title_music_bus_index, 0) as AudioEffectEQ10
	assert(title_equalizer.get_band_gain_db(0) == 5.0)
	assert(title_equalizer.get_band_gain_db(1) == 5.0)
	assert(title_equalizer.get_band_gain_db(2) == 4.0)
	assert(title_equalizer.get_band_gain_db(3) == 2.0)
	assert(title_equalizer.get_band_gain_db(4) == 0.5)
	assert(scene.menu_buttons[0].name == "PlayButton")
	assert(scene.menu_buttons[1].name == "SettingsButton")
	assert(scene.bite_hint != null)
	assert(scene.bite_hint.get_node("Key") is Sprite2D)
	assert(scene.bite_hint.get_node("Text") is Sprite2D)
	assert(scene.player_sprite != null)
	assert(scene.get_node("Logo") is Sprite2D)
	assert(scene.selected_index == 0)
	assert(scene.player_sprite.global_position.x < scene.menu_buttons[0].global_position.x)

	scene.selected_index = 1
	scene._update_selection(false)
	assert(scene.player_sprite.global_position.y > scene.menu_buttons[0].global_position.y)

	scene._open_settings_panel()
	assert(scene.settings_panel != null)
	assert(scene.settings_panel.get_node("Panel") is Sprite2D)
	assert(scene.settings_row_highlights.size() == 2)
	assert(scene.settings_slider_fills.size() == 2)
	assert(scene.settings_slider_knobs.size() == 2)
	assert(scene.settings_slider_fills[0] is Sprite2D)
	assert(scene.settings_slider_knobs[0] is Sprite2D)
	AudioSettings.set_bgm_volume(1.0, false)
	scene.stage_bgm.refresh_volume_from_settings()
	var previous_bgm_volume: float = AudioSettings.bgm_volume
	scene._adjust_settings_volume(-0.1)
	assert(AudioSettings.bgm_volume < previous_bgm_volume)
	assert(scene.stage_bgm.active_volume_db < scene.stage_bgm.active_base_volume_db)
	AudioSettings.set_bgm_volume(1.0, false)
	scene.stage_bgm.refresh_volume_from_settings()
	scene._close_settings_panel()
	assert(scene.settings_panel == null)

	print("TITLE_SCREEN_CHECK_OK")
	scene.queue_free()
	await process_frame
	quit(0)
