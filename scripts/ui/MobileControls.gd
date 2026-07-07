# 2026-07-07: スマホ向けの横移動パッド、ジャンプ、噛み操作を提供する。
class_name MobileControls
extends CanvasLayer

const MOVE_PAD_BASE_TEXTURE_PATH := "res://assets/ui/mobile/mobile_move_pad_base.png"
const MOVE_PAD_KNOB_TEXTURE_PATH := "res://assets/ui/mobile/mobile_move_pad_knob.png"
const JUMP_BUTTON_TEXTURE_PATH := "res://assets/ui/mobile/mobile_jump_button.png"
const JUMP_BUTTON_PRESSED_TEXTURE_PATH := "res://assets/ui/mobile/mobile_jump_button_pressed.png"
const BITE_BUTTON_TEXTURE_PATH := "res://assets/ui/mobile/mobile_bite_button.png"
const BITE_BUTTON_PRESSED_TEXTURE_PATH := "res://assets/ui/mobile/mobile_bite_button_pressed.png"
const REPLAY_BUTTON_TEXTURE_PATH := "res://assets/ui/mobile/mobile_replay_button.png"
const REPLAY_BUTTON_PRESSED_TEXTURE_PATH := "res://assets/ui/mobile/mobile_replay_button_pressed.png"

@export var force_visible := false # PC上の確認用にスマホUIを強制表示する。
@export var show_replay_button := true # リプレイボタンを表示するか。
@export_range(0.0, 1.0, 0.01) var idle_opacity := 0.78 # 未操作時の透明度。
@export_range(32.0, 140.0, 1.0) var move_dead_zone := 22.0 # 横移動パッドの無反応範囲。
@export_range(40.0, 180.0, 1.0) var move_radius := 78.0 # 横移動パッドの最大ドラッグ距離。

var move_base: TextureRect # 横移動パッドの背景。
var move_knob: TextureRect # 横移動パッドのつまみ。
var jump_button: TextureButton # ジャンプボタン。
var bite_button: TextureButton # 噛みボタン。
var replay_button: TextureButton # リプレイボタン。
var move_touch_index := -1 # 横移動パッドを操作中のタッチID。
var move_origin := Vector2.ZERO # 横移動パッドの中心座標。
var move_rest_origin := Vector2.ZERO # 未操作時の横移動パッド中心。
var move_axis := 0.0 # 現在の横入力値。

# スマホ操作UIを構築する。
func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = force_visible or DeviceProfile.should_use_mobile_controls()
	if not visible:
		return
	_build_move_pad()
	_build_action_buttons()
	_update_layout()
	get_tree().root.size_changed.connect(_update_layout)

# 横移動の押下状態を毎フレーム既存Input actionへ反映する。
func _process(_delta: float) -> void:
	if not visible:
		return
	if move_axis < -0.15:
		Input.action_press("move_left", absf(move_axis))
		Input.action_release("move_right")
	elif move_axis > 0.15:
		Input.action_press("move_right", absf(move_axis))
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

# タッチやドラッグを受け取り、横移動パッドだけ独自処理する。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

# 解放時に仮想入力を残さない。
func _exit_tree() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("bite")
	Input.action_release("replay")

# 横移動パッドを作る。
func _build_move_pad() -> void:
	move_base = TextureRect.new()
	move_base.name = "MovePadBase"
	move_base.texture = load(MOVE_PAD_BASE_TEXTURE_PATH) as Texture2D
	move_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_base.modulate.a = idle_opacity
	add_child(move_base)

	move_knob = TextureRect.new()
	move_knob.name = "MovePadKnob"
	move_knob.texture = load(MOVE_PAD_KNOB_TEXTURE_PATH) as Texture2D
	move_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_knob.modulate.a = idle_opacity
	add_child(move_knob)

# 右側のジャンプ、噛み、リプレイボタンを作る。
func _build_action_buttons() -> void:
	jump_button = _create_action_button("JumpButton", JUMP_BUTTON_TEXTURE_PATH, JUMP_BUTTON_PRESSED_TEXTURE_PATH, "jump")
	bite_button = _create_action_button("BiteButton", BITE_BUTTON_TEXTURE_PATH, BITE_BUTTON_PRESSED_TEXTURE_PATH, "bite")
	replay_button = _create_action_button("ReplayButton", REPLAY_BUTTON_TEXTURE_PATH, REPLAY_BUTTON_PRESSED_TEXTURE_PATH, "replay")
	replay_button.visible = show_replay_button

# 画面サイズに応じて操作UIを配置する。
func _update_layout() -> void:
	if move_base == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_bottom := 34.0
	move_base.position = Vector2(42, viewport_size.y - 204)
	move_base.size = Vector2(210, 150)
	move_rest_origin = move_base.position + move_base.size * 0.5
	if move_touch_index < 0:
		move_origin = move_rest_origin
	_update_move_knob()

	bite_button.size = Vector2(214, 214)
	bite_button.position = Vector2(viewport_size.x - 320, move_rest_origin.y - bite_button.size.y * 0.5)
	jump_button.size = Vector2(132, 132)
	jump_button.position = bite_button.position + Vector2(118, -116)
	replay_button.position = Vector2(viewport_size.x - 120, 28)
	replay_button.size = Vector2(96, 96)

# 既存Input actionへ対応するTextureButtonを作る。
func _create_action_button(button_name: String, normal_path: String, pressed_path: String, action_name: StringName) -> TextureButton:
	var button := TextureButton.new()
	button.name = button_name
	button.texture_normal = load(normal_path) as Texture2D
	button.texture_pressed = load(pressed_path) as Texture2D
	button.texture_hover = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.modulate.a = idle_opacity
	button.button_down.connect(func():
		button.modulate.a = 1.0
		Input.action_press(action_name)
	)
	button.button_up.connect(func():
		button.modulate.a = idle_opacity
		Input.action_release(action_name)
	)
	add_child(button)
	return button

# タッチ開始と終了を処理する。
func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and move_touch_index < 0 and _is_inside_move_pad(event.position):
		move_touch_index = event.index
		move_origin = event.position
		move_base.position = move_origin - move_base.size * 0.5
		_set_move_axis_from_position(event.position)
	elif not event.pressed and event.index == move_touch_index:
		move_touch_index = -1
		move_axis = 0.0
		move_origin = move_rest_origin
		move_base.position = move_origin - move_base.size * 0.5
		_update_move_knob()

# 横移動パッドをドラッグ中なら入力値を更新する。
func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == move_touch_index:
		_set_move_axis_from_position(event.position)

# 指定座標が横移動パッドの反応範囲内かを返す。
func _is_inside_move_pad(position: Vector2) -> bool:
	var rect := Rect2(move_base.position - Vector2(22, 22), move_base.size + Vector2(44, 44))
	return rect.has_point(position)

# 座標から横入力値を計算する。
func _set_move_axis_from_position(position: Vector2) -> void:
	var delta_x := clampf(position.x - move_origin.x, -move_radius, move_radius)
	move_axis = 0.0 if absf(delta_x) < move_dead_zone else delta_x / move_radius
	_update_move_knob()

# 横移動パッドのつまみ位置を入力値に合わせる。
func _update_move_knob() -> void:
	if move_knob == null:
		return
	var knob_size := Vector2(74, 74)
	move_knob.size = knob_size
	move_knob.position = move_origin - knob_size * 0.5 + Vector2(move_axis * move_radius, 0.0)
