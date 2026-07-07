# 2026-07-06: ロゴ、噛み選択、ステージセレクト遷移を持つタイトル画面。
extends Node2D

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const StageBgmScript := preload("res://scripts/stage/StageBgm.gd")
const BossMusicBusScript := preload("res://scripts/boss/audio/BossMusicBus.gd")
const AudioSettings := preload("res://scripts/audio/AudioSettings.gd")
const DeviceProfileScript := preload("res://scripts/platform/DeviceProfile.gd")

const LOGO_TEXTURE_PATH := "res://assets/ui/title/rebite_title_logo.png"
const BUTTON_FRAME_TEXTURE_PATH := "res://assets/ui/title/title_button_frame.png"
const FLOOR_TILE_TEXTURE_PATH := "res://assets/ui/title/title_floor_tile.png"
const SETTINGS_PANEL_TEXTURE_PATH := "res://assets/ui/title/title_settings_panel.png"
const SLIDER_FRAME_TEXTURE_PATH := "res://assets/ui/title/title_slider_frame.png"
const SLIDER_FILL_TEXTURE_PATH := "res://assets/ui/title/title_slider_fill.png"
const SLIDER_KNOB_TEXTURE_PATH := "res://assets/ui/title/title_slider_knob.png"
const PLAY_TEXT_TEXTURE_PATH := "res://assets/ui/title/title_text_play.png"
const SETTINGS_TEXT_TEXTURE_PATH := "res://assets/ui/title/title_text_options.png"
const BACK_TEXT_TEXTURE_PATH := "res://assets/ui/title/title_text_back.png"
const BGM_TEXT_TEXTURE_PATH := "res://assets/ui/title/title_text_bgm.png"
const SE_TEXT_TEXTURE_PATH := "res://assets/ui/title/title_text_se.png"
const BITE_HINT_TEXT_TEXTURE_PATH := "res://assets/ui/title/title_text_bite_hint.png"
const BITE_HINT_KEY_TEXTURE_PATH := "res://assets/ui/bite_hint_key_k.png"
const BITE_HINT_TOUCH_TEXTURE_PATH := "res://assets/ui/mobile/mobile_bite_button.png"
const BITE_HINT_TOP_FANG_TEXTURE_PATH := "res://assets/ui/bite_hint_top_fang.png"
const BITE_HINT_BOTTOM_FANG_TEXTURE_PATH := "res://assets/ui/bite_hint_bottom_fang.png"

const BUTTON_SIZE := Vector2(392, 124)
const BUTTON_POSITIONS := [Vector2(640, 450), Vector2(640, 575)]
const PLAYER_SCALE := Vector2(1.9, 1.9)
const PLAYER_X_OFFSET := -280.0
const BITE_LUNGE_DISTANCE := 86.0
const SETTINGS_ROW_POSITIONS: Array[Vector2] = [Vector2(640, 360), Vector2(640, 435)]
const SETTINGS_SLIDER_WIDTH := 300.0

@export_file("*.wav", "*.ogg") var title_bgm_path := "res://assets/bgm/rebite_title_bass_clean_ending.wav" # タイトル画面で再生するBGM。
@export var title_music_bus_name := &"TitleMusic" # タイトルBGMへEQをかける専用Audio Bus名。

var selected_index := 0 # 現在選択中のメニュー番号。
var menu_buttons: Array[Node2D] = [] # タイトルメニューのボタン。
var player_sprite: AnimatedSprite2D # メニューを噛んで選択するプレイヤー。
var stage_bgm: Node # タイトルBGM。
var title_music_bus: Node # タイトルBGM用のEQ Bus。
var moving := false # 噛み演出中かどうか。
var settings_panel: CanvasLayer # 設定表示。
var logo_texture: Texture2D # タイトルロゴ画像。
var button_frame_texture: Texture2D # ボタン枠画像。
var floor_tile_texture: Texture2D # タイトル床のタイル画像。
var settings_panel_texture: Texture2D # 設定パネル枠画像。
var slider_frame_texture: Texture2D # 音量バー枠画像。
var slider_fill_texture: Texture2D # 音量バーの塗り画像。
var slider_knob_texture: Texture2D # 音量バーのつまみ画像。
var play_text_texture: Texture2D # 遊ぶ文字画像。
var settings_text_texture: Texture2D # 設定文字画像。
var back_text_texture: Texture2D # 戻る文字画像。
var bgm_text_texture: Texture2D # BGM文字画像。
var se_text_texture: Texture2D # SE文字画像。
var bite_hint_text_texture: Texture2D # 噛み操作説明の文字画像。
var bite_hint_key_texture: Texture2D # Kキートップ画像。
var bite_hint_top_fang_texture: Texture2D # 上牙マーカー画像。
var bite_hint_bottom_fang_texture: Texture2D # 下牙マーカー画像。
var bite_hint: Node2D # Kで噛んで選ぶことを示す表示。
var settings_selected_audio_index := 0 # 設定画面で選択中の音量行。
var settings_row_highlights: Array[ColorRect] = [] # 設定画面の選択行表示。
var settings_slider_fills: Array[Sprite2D] = [] # 設定画面の音量バー塗り。
var settings_slider_knobs: Array[Sprite2D] = [] # 設定画面の音量バーつまみ。

# タイトル画面を構成する。
func _ready() -> void:
	AudioSettings.load_settings()
	_load_textures()
	_build_background()
	_build_bgm()
	_build_logo()
	_build_menu_buttons()
	_build_player()
	_update_selection(false)

# 選択移動と噛み選択を受け付ける。
func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return
	if settings_panel != null:
		if event.is_action_pressed("move_left") or _is_key_pressed(event, [KEY_LEFT, KEY_A]):
			_adjust_settings_volume(-0.05)
		elif event.is_action_pressed("move_right") or _is_key_pressed(event, [KEY_RIGHT, KEY_D]):
			_adjust_settings_volume(0.05)
		elif _is_key_pressed(event, [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
			settings_selected_audio_index = 1 - settings_selected_audio_index
			_refresh_settings_panel()
		elif event.is_action_pressed("bite") or _is_key_pressed(event, [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_K]):
			_close_settings_panel()
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or _is_key_pressed(event, [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
		selected_index = 1 - selected_index
		_update_selection()
	elif event.is_action_pressed("bite"):
		_bite_selected_button()

# 背景と床を作る。
func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color(0.027, 0.03, 0.048)
	background.size = Vector2(1280, 720)
	background.z_index = -30
	add_child(background)

	var floor := Node2D.new()
	floor.name = "PurpleBlockFloor"
	floor.z_index = -20
	add_child(floor)
	for y in range(0, 128, 32):
		for x in range(-16, 1296, 48):
			var tile := Sprite2D.new()
			tile.texture = floor_tile_texture
			tile.centered = false
			tile.position = Vector2(x, 624 + y)
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.modulate = Color(0.88, 0.82, 1.0) if int((x + y) / 48.0) % 2 == 0 else Color(1.0, 0.92, 1.0)
			floor.add_child(tile)

# タイトル用テクスチャを読み込む。
func _load_textures() -> void:
	logo_texture = load(LOGO_TEXTURE_PATH) as Texture2D
	button_frame_texture = load(BUTTON_FRAME_TEXTURE_PATH) as Texture2D
	floor_tile_texture = load(FLOOR_TILE_TEXTURE_PATH) as Texture2D
	settings_panel_texture = load(SETTINGS_PANEL_TEXTURE_PATH) as Texture2D
	slider_frame_texture = load(SLIDER_FRAME_TEXTURE_PATH) as Texture2D
	slider_fill_texture = load(SLIDER_FILL_TEXTURE_PATH) as Texture2D
	slider_knob_texture = load(SLIDER_KNOB_TEXTURE_PATH) as Texture2D
	play_text_texture = load(PLAY_TEXT_TEXTURE_PATH) as Texture2D
	settings_text_texture = load(SETTINGS_TEXT_TEXTURE_PATH) as Texture2D
	back_text_texture = load(BACK_TEXT_TEXTURE_PATH) as Texture2D
	bgm_text_texture = load(BGM_TEXT_TEXTURE_PATH) as Texture2D
	se_text_texture = load(SE_TEXT_TEXTURE_PATH) as Texture2D
	bite_hint_text_texture = load(BITE_HINT_TEXT_TEXTURE_PATH) as Texture2D
	bite_hint_key_texture = load(BITE_HINT_TOUCH_TEXTURE_PATH if DeviceProfileScript.should_use_touch_bite_hint() else BITE_HINT_KEY_TEXTURE_PATH) as Texture2D
	bite_hint_top_fang_texture = load(BITE_HINT_TOP_FANG_TEXTURE_PATH) as Texture2D
	bite_hint_bottom_fang_texture = load(BITE_HINT_BOTTOM_FANG_TEXTURE_PATH) as Texture2D

# BGMを作成する。
func _build_bgm() -> void:
	title_music_bus = BossMusicBusScript.new()
	title_music_bus.name = "TitleMusicBus"
	title_music_bus.bus_name = title_music_bus_name
	add_child(title_music_bus)
	title_music_bus.setup()

	stage_bgm = StageBgmScript.new()
	stage_bgm.name = "StageBgm"
	add_child(stage_bgm)
	stage_bgm.bgm_path = title_bgm_path
	stage_bgm.bus_name = title_music_bus.bus_name
	stage_bgm.setup()

# ロゴを配置する。
func _build_logo() -> void:
	var logo := Sprite2D.new()
	logo.name = "Logo"
	logo.texture = logo_texture
	logo.centered = true
	logo.position = Vector2(640, 190)
	logo.scale = Vector2(0.43, 0.43)
	logo.z_index = -5
	add_child(logo)

# メニューの2ボタンを作る。
func _build_menu_buttons() -> void:
	menu_buttons.append(_create_menu_button("PlayButton", play_text_texture, BUTTON_POSITIONS[0]))
	menu_buttons.append(_create_menu_button("SettingsButton", settings_text_texture, BUTTON_POSITIONS[1]))
	for button in menu_buttons:
		add_child(button)
	_build_bite_hint()

# 枠Spriteと文字Spriteを分けたボタンを作る。
func _create_menu_button(button_name: String, text_texture: Texture2D, position_value: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = button_name
	root.position = position_value

	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.color = Color(0.98, 0.72, 0.18, 0.0)
	glow.position = -BUTTON_SIZE * 0.5 + Vector2(18, 16)
	glow.size = BUTTON_SIZE - Vector2(36, 32)
	root.add_child(glow)

	var frame := Sprite2D.new()
	frame.name = "Frame"
	frame.texture = button_frame_texture
	frame.centered = true
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(frame)

	var text := Sprite2D.new()
	text.name = "Text"
	text.texture = text_texture
	text.centered = true
	text.position = Vector2(0, -1)
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(text)

	return root

# 選択中ボタンの近くにK噛み選択ヒントを作る。
func _build_bite_hint() -> void:
	bite_hint = Node2D.new()
	bite_hint.name = "BiteHint"
	bite_hint.z_index = 8
	add_child(bite_hint)

	var key := Sprite2D.new()
	key.name = "Key"
	key.texture = bite_hint_key_texture
	key.centered = true
	key.position = Vector2(44, 0)
	key.scale = Vector2(0.34, 0.34) if DeviceProfileScript.should_use_touch_bite_hint() else Vector2(1.35, 1.35)
	key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bite_hint.add_child(key)

	var text := Sprite2D.new()
	text.name = "Text"
	text.texture = bite_hint_text_texture
	text.centered = true
	text.position = Vector2(110, 1)
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bite_hint.add_child(text)

	for config in [
		{"name": "TopFang", "texture": bite_hint_top_fang_texture, "position": Vector2(-8, -18), "flip_v": false},
		{"name": "BottomFang", "texture": bite_hint_bottom_fang_texture, "position": Vector2(-8, 20), "flip_v": true},
	]:
		var fang := Sprite2D.new()
		fang.name = config.name
		fang.texture = config.texture
		fang.centered = true
		fang.position = config.position
		fang.scale = Vector2(0.75, 0.75)
		fang.flip_v = config.flip_v
		fang.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bite_hint.add_child(fang)

# プレイヤーキャラクターを作る。
func _build_player() -> void:
	player_sprite = AnimatedSprite2D.new()
	player_sprite.name = "Player"
	var frames := SpriteFrameBuilder.from_folder("res://assets/player/walk", &"walk", 8.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/player/bite", &"bite", 12.0, false)
	player_sprite.sprite_frames = frames
	player_sprite.scale = PLAYER_SCALE
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.play(&"walk")
	add_child(player_sprite)

# 選択中ボタンとプレイヤー位置を更新する。
func _update_selection(animated := true) -> void:
	for i in menu_buttons.size():
		var button := menu_buttons[i]
		var selected := i == selected_index
		button.scale = Vector2(1.05, 1.05) if selected else Vector2.ONE
		var glow := button.get_node("Glow") as ColorRect
		glow.color.a = 0.23 if selected else 0.0
	var target_position := _player_position_for_index(selected_index)
	if animated:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(player_sprite, "global_position", target_position, 0.12)
	else:
		player_sprite.global_position = target_position
	bite_hint.global_position = menu_buttons[selected_index].global_position + Vector2(BUTTON_SIZE.x * 0.5 + 16, -4)
	player_sprite.flip_h = false
	player_sprite.play(&"walk")

# 指定ボタンの左側に立つプレイヤー位置を返す。
func _player_position_for_index(index: int) -> Vector2:
	return menu_buttons[index].global_position + Vector2(PLAYER_X_OFFSET, 12)

# 選択中ボタンへ噛みついて実行する。
func _bite_selected_button() -> void:
	moving = true
	var selected_button := menu_buttons[selected_index]
	var start_position := player_sprite.global_position
	var bite_position := selected_button.global_position + Vector2(-BUTTON_SIZE.x * 0.42, 28)
	player_sprite.play(&"bite")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player_sprite, "global_position", bite_position, 0.10)
	tween.tween_callback(func(): _break_menu_button(selected_button))
	tween.tween_interval(0.16)
	tween.tween_property(player_sprite, "global_position", start_position, 0.10)
	tween.tween_callback(_activate_selected_button)

# 噛まれたボタンを砕いて見せる。
func _break_menu_button(button: Node2D) -> void:
	button.visible = false
	for i in 28:
		var shard := ColorRect.new()
		shard.color = [Color(0.96, 0.71, 0.2), Color(0.58, 0.25, 0.76), Color(0.12, 0.06, 0.18)][i % 3]
		shard.size = Vector2(randf_range(8.0, 20.0), randf_range(6.0, 18.0))
		shard.global_position = button.global_position + Vector2(randf_range(-150.0, 150.0), randf_range(-36.0, 36.0))
		add_child(shard)
		var angle := randf_range(-PI * 0.85, PI * 0.15)
		var distance := randf_range(58.0, 150.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.40)
		tween.tween_property(shard, "rotation", randf_range(-2.8, 2.8), 0.40)
		tween.tween_property(shard, "modulate:a", 0.0, 0.40)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

# 選択結果を実行する。
func _activate_selected_button() -> void:
	if selected_index == 0:
		get_tree().change_scene_to_file("res://stage/StageSelect.tscn")
	else:
		_open_settings_panel()
		_restore_menu_buttons()
	moving = false

# 設定パネルを表示する。
func _open_settings_panel() -> void:
	settings_panel = CanvasLayer.new()
	settings_panel.name = "SettingsPanel"
	add_child(settings_panel)
	settings_row_highlights.clear()
	settings_slider_fills.clear()
	settings_slider_knobs.clear()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.size = Vector2(1280, 720)
	settings_panel.add_child(dim)

	var panel := Sprite2D.new()
	panel.name = "Panel"
	panel.texture = settings_panel_texture
	panel.centered = true
	panel.position = Vector2(640, 365)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(panel)

	var title := Sprite2D.new()
	title.texture = settings_text_texture
	title.centered = true
	title.position = Vector2(640, 292)
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(title)

	_build_audio_setting_row(0, bgm_text_texture)
	_build_audio_setting_row(1, se_text_texture)

	var back_frame := Sprite2D.new()
	back_frame.texture = button_frame_texture
	back_frame.centered = true
	back_frame.position = Vector2(640, 505)
	back_frame.scale = Vector2(0.62, 0.62)
	back_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(back_frame)

	var back_text := Sprite2D.new()
	back_text.texture = back_text_texture
	back_text.centered = true
	back_text.position = Vector2(640, 506)
	back_text.scale = Vector2(0.68, 0.68)
	back_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(back_text)
	_refresh_settings_panel()

# BGM/SE音量行を作る。
func _build_audio_setting_row(index: int, label_texture: Texture2D) -> void:
	var row_position := SETTINGS_ROW_POSITIONS[index]
	var highlight := ColorRect.new()
	highlight.color = Color(1.0, 0.72, 0.16, 0.0)
	highlight.position = row_position + Vector2(-230, -28)
	highlight.size = Vector2(460, 56)
	settings_panel.add_child(highlight)
	settings_row_highlights.append(highlight)

	var label := Sprite2D.new()
	label.texture = label_texture
	label.centered = true
	label.position = row_position + Vector2(-175, 0)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(label)

	var frame := Sprite2D.new()
	frame.texture = slider_frame_texture
	frame.centered = true
	frame.position = row_position + Vector2(75, 0)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(frame)

	var fill := Sprite2D.new()
	fill.texture = slider_fill_texture
	fill.centered = false
	fill.region_enabled = true
	fill.region_rect = Rect2(0, 0, SETTINGS_SLIDER_WIDTH, 10)
	fill.position = row_position + Vector2(-75, -5)
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(fill)
	settings_slider_fills.append(fill)

	var knob := Sprite2D.new()
	knob.texture = slider_knob_texture
	knob.centered = true
	knob.position = row_position + Vector2(225, 0)
	knob.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_panel.add_child(knob)
	settings_slider_knobs.append(knob)

# 設定パネル上の選択行とバーの長さを更新する。
func _refresh_settings_panel() -> void:
	for i in settings_row_highlights.size():
		settings_row_highlights[i].color.a = 0.18 if i == settings_selected_audio_index else 0.0
	var values := [AudioSettings.bgm_volume, AudioSettings.se_volume]
	for i in settings_slider_fills.size():
		var value := clampf(float(values[i]), 0.0, 1.0)
		settings_slider_fills[i].region_rect = Rect2(0, 0, maxf(1.0, SETTINGS_SLIDER_WIDTH * value), 10)
		settings_slider_knobs[i].position.x = SETTINGS_ROW_POSITIONS[i].x - 75.0 + SETTINGS_SLIDER_WIDTH * value

# 選択中のBGM/SE音量を調整する。
func _adjust_settings_volume(delta: float) -> void:
	if settings_selected_audio_index == 0:
		AudioSettings.set_bgm_volume(AudioSettings.bgm_volume + delta)
		if stage_bgm != null and stage_bgm.has_method("refresh_volume_from_settings"):
			stage_bgm.refresh_volume_from_settings()
	else:
		AudioSettings.set_se_volume(AudioSettings.se_volume + delta)
	_refresh_settings_panel()

# 設定パネルを閉じる。
func _close_settings_panel() -> void:
	if settings_panel != null:
		settings_panel.queue_free()
		settings_panel = null
	_update_selection(false)

# 砕いたメニューボタンを戻す。
func _restore_menu_buttons() -> void:
	for button in menu_buttons:
		button.visible = true

# 指定キー群の押下を返す。
func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return keys.has(key_event.keycode)
