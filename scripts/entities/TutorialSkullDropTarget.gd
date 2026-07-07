# 2026-07-07: Stage0専用にAIを止めたSkullMonster派生の噛み対象。
class_name TutorialSkullDropTarget
extends SkullMonster

signal bitten
signal drop_started
signal drop_finished

@export var starts_available := false # 初期状態でプレイヤーが噛めるか。
@export var scripted_drop_delay := 0.18 # 記憶破壊後に落下DASHを始めるまでの間。

var available := false # 現在プレイヤーが噛めるか。
var scripted_tween: Tween # Stage0演出用の移動Tween。

# 通常Skullの見た目と記憶タグだけ初期化し、AI StateMachineは起動しない。
func _ready() -> void:
	remember_spawn_position()
	_build_animations()
	_setup_replay_outline_material()
	set_attack_hitbox_active(false)
	set_available(starts_available)

# Stage0演出用なので通常AIは動かさない。
func _physics_process(_delta: float) -> void:
	pass

# プレイヤーが噛める状態を切り替える。
func set_available(active: bool) -> void:
	available = active
	if active:
		_commit_scripted_right_dash(false)
	else:
		if memory_tag != null:
			memory_tag.hide_tag()
	if memory_tag != null:
		memory_tag.set_bite_hint_active(false)

# 影キャラ用にタグは見せるが、プレイヤー噛み判定は開かない。
func prepare_scripted_memory_hint(active: bool) -> void:
	available = false
	if active:
		_commit_scripted_right_dash(false)
		if memory_tag != null:
			memory_tag.set_bite_hint_active(true)
	else:
		if memory_tag != null:
			memory_tag.hide_tag()

# 影キャラの実演としてDASH記憶を割り、指定位置へ運ばれる。
func play_scripted_dash_to(destination: Vector2, duration: float, reform_after := true) -> void:
	_kill_scripted_tween()
	available = false
	_commit_scripted_right_dash(false)
	if memory_tag != null:
		memory_tag.begin_breaking(last_record)
	set_dash_direction_visual(Vector2.RIGHT)
	set_replay_outline_active(true)
	play_animation(&"dash")
	set_active_action_record(last_record)
	scripted_tween = create_tween()
	scripted_tween.set_trans(Tween.TRANS_QUAD)
	scripted_tween.set_ease(Tween.EASE_IN_OUT)
	scripted_tween.tween_property(self, "global_position", destination, duration)
	scripted_tween.tween_callback(func():
		set_replay_outline_active(false)
		clear_active_action_record(last_record)
		velocity = Vector2.ZERO
		play_animation(&"idle")
		if reform_after:
			_commit_scripted_right_dash(true)
			if memory_tag != null:
				memory_tag.set_bite_hint_active(false)
		else:
			if memory_tag != null:
				memory_tag.hide_tag()
	)

# プレイヤー噛み後、右の穴へDASHして落下する。
func play_drop_dash(hole_center_x: float, fall_y: float) -> void:
	_kill_scripted_tween()
	available = false
	drop_started.emit()
	set_dash_direction_visual(Vector2.RIGHT)
	set_replay_outline_active(true)
	play_animation(&"dash")
	set_active_action_record(last_record)
	var dash_end := Vector2(hole_center_x, global_position.y)
	scripted_tween = create_tween()
	scripted_tween.set_trans(Tween.TRANS_QUAD)
	scripted_tween.set_ease(Tween.EASE_IN)
	scripted_tween.tween_interval(scripted_drop_delay)
	scripted_tween.tween_property(self, "global_position", dash_end, 0.46)
	scripted_tween.tween_callback(func():
		clear_active_action_record(last_record)
		play_animation(&"idle")
	)
	scripted_tween.tween_property(self, "global_position", Vector2(hole_center_x, fall_y), 0.92).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scripted_tween.tween_callback(func():
		set_replay_outline_active(false)
		visible = false
		drop_finished.emit()
	)

# Stage0専用のDASHではActionBreakGroupを速度条件なしで壊せる。
func can_break_action_group(_group: Node = null) -> bool:
	return active_action_record != null and active_action_record.action_name == &"dash"

# Stage0では利用可能な記憶があれば噛める。
func is_biteable() -> bool:
	return available and last_record != null and last_record.is_available and memory_tag != null and memory_tag.is_available()

# K入力時点で噛み成功を確定し、タグを消費する。
func begin_committed_bite(player: Node, record: Resource) -> bool:
	return receive_committed_bite(player, record)

# 同一記憶の二重使用を拒否してStage0演出へ通知する。
func receive_committed_bite(_player: Node, record: Resource = null) -> bool:
	if not available:
		return false
	if record == null:
		record = last_record
	if not consume_memory_record(record):
		return false
	available = false
	bitten.emit()
	return true

# 古い噛み処理との互換口。
func receive_bite(player: Node) -> void:
	receive_committed_bite(player, last_record)

# 記憶タグを右DASHで作り直す。
func _commit_scripted_right_dash(reform := false) -> void:
	var record := build_dash_record(Vector2.RIGHT, &"NATURAL")
	commit_memory_record(record, &"NATURAL", reform)

func _kill_scripted_tween() -> void:
	if scripted_tween != null and scripted_tween.is_valid():
		scripted_tween.kill()
	scripted_tween = null
	set_replay_outline_active(false)
