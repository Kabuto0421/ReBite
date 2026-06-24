# 2026-06-23: ボスギミック接触の全体停止、素材色FX、変形、反動を共通管理する。
class_name BossImpactFeedback
extends Node

signal impact_started(impact_id: StringName) # ヒットストップ開始を通知する。
signal impact_finished(impact_id: StringName) # 結果処理の再開を通知する。

@export_group("Hit Stop")
@export_range(0.0, 0.3, 0.01) var socket_hold_time := 0.05 # 岩がSocketへ固定された時の停止時間。
@export_range(0.0, 0.3, 0.01) var landing_hold_time := 0.07 # 岩が着地した時の停止時間。
@export_range(0.0, 0.3, 0.01) var rock_smash_hold_time := 0.06 # SMASHが岩へ接触した時の停止時間。
@export_range(0.0, 0.3, 0.01) var wall_hold_time := 0.14 # Boarが最終壁へ激突した時の停止時間。

@export_group("Camera")
@export_range(0.0, 20.0, 0.5) var landing_shake_strength := 3.0 # 岩着地時の揺れ幅。
@export_range(0.0, 20.0, 0.5) var wall_shake_strength := 12.0 # 最終壁激突時の揺れ幅。

@export_group("Object Colors")
@export_color_no_alpha var socket_color := Color(0.48, 1.15, 1.35) # Socket発光へ合わせるシアン。
@export_color_no_alpha var rock_color := Color(0.94, 0.88, 0.76) # 岩と粉塵へ合わせる石色。
@export_color_no_alpha var smash_color := Color(1.15, 0.76, 0.42) # BoarとSMASHへ合わせる暖色。
@export_color_no_alpha var wall_color := Color(0.92, 0.72, 0.48) # 壁と亀裂へ合わせる土色。

@export_group("Effect Textures")
@export_file("*.png") var burst_path := "res://assets/boss/gimmicks/frames/destruction_fx_00.png" # 小さい接触バースト。
@export_file("*.png") var star_path := "res://assets/boss/gimmicks/frames/destruction_fx_01.png" # 放射状の着地衝撃。
@export_file("*.png") var hold_path := "res://assets/boss/gimmicks/frames/destruction_fx_02.png" # 停止中の衝撃残光。
@export_file("*.png") var debris_path := "res://assets/boss/gimmicks/frames/destruction_fx_03.png" # 解除後の小破片。
@export_file("*.png") var dust_path := "res://assets/boss/gimmicks/frames/destruction_fx_04.png" # 解除後の粉塵。
@export_file("*.png") var streak_path := "res://assets/boss/gimmicks/frames/destruction_fx_05.png" # 横方向衝突の閃光。

var stage: Node # Stage10本体。
var boss: Node # 変形対象のBossBoar。
var stopper: Node # Socket表示を持つStopper。
var holding := false # 現在ヒットストップ中か。
var active_impact_id: StringName # 現在停止中のImpact ID。
var previous_tree_paused := false # 開始前のSceneTree pause状態。
var active_targets: Array[Dictionary] = [] # 復元対象と元scale。
var active_contact_fx: Sprite2D # 停止中に表示する接触FX。
var pending_impacts: Array[Dictionary] = [] # 同時接触を順番に処理するQueue。

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Stage10内の意味イベントを登録し、接触後続行の待機を有効化する。
func setup(
	stage_node: Node,
	boss_node: Node,
	falling_trap: Node,
	timed_trap: Node,
	rock_a: Node,
	rock_b: Node,
	stopper_node: Node,
	final_wall: Node
) -> void:
	stage = stage_node
	boss = boss_node
	stopper = stopper_node
	for rock in [rock_a, rock_b]:
		rock.set_impact_feedback_enabled(true)
		rock.smash_contacted.connect(_on_rock_smash_contacted)
	for trap in [falling_trap, timed_trap]:
		trap.set_impact_feedback_enabled(true)
		trap.landing_contact.connect(_on_landing_contact)
	final_wall.set_impact_feedback_enabled(true)
	final_wall.wall_contact.connect(_on_wall_contact)
	stopper.rock_locked.connect(_on_rock_locked)

# SMASH接触を止め、解除後に岩のSocket移動を始める。
func _on_rock_smash_contacted(rock: Node, impact_position: Vector2) -> void:
	_request_impact({
		"id": &"rock_smash",
		"position": impact_position,
		"duration": rock_smash_hold_time,
		"shake": 0.0,
		"color": smash_color,
		"contact_path": streak_path,
		"hold_path": star_path,
		"aftermath_path": debris_path,
		"effect_scale": 1.8,
		"targets": [boss.sprite, rock.sprite],
		"multipliers": [Vector2(1.08, 0.92), Vector2(0.88, 1.10)],
		"continuation": Callable(rock, "continue_socket_move"),
	})

# 岩着地を止め、解除後に命中結果を確定する。
func _on_landing_contact(trap: Node, impact_position: Vector2, hit: bool) -> void:
	var targets: Array = [trap.rock_sprite]
	var multipliers: Array = [Vector2(1.14, 0.82)]
	if hit and is_instance_valid(boss):
		targets.append(boss.sprite)
		multipliers.append(Vector2(0.96, 1.04))
	_request_impact({
		"id": &"rock_landing",
		"position": impact_position,
		"duration": landing_hold_time,
		"shake": landing_shake_strength,
		"color": rock_color,
		"contact_path": star_path,
		"hold_path": hold_path,
		"aftermath_path": dust_path,
		"effect_scale": 1.7,
		"targets": targets,
		"multipliers": multipliers,
		"continuation": Callable(trap, "complete_landing_after_impact"),
	})

# Socket固定をシアン発光と小さい変形で明示する。
func _on_rock_locked(rock: Node) -> void:
	_request_impact({
		"id": &"socket_lock",
		"position": stopper.socket_sprite.global_position,
		"duration": socket_hold_time,
		"shake": 0.0,
		"color": socket_color,
		"contact_path": burst_path,
		"hold_path": hold_path,
		"aftermath_path": "",
		"effect_scale": 1.4,
		"targets": [rock.sprite, stopper.socket_sprite],
		"multipliers": [Vector2(1.08, 0.92), Vector2(1.04, 0.96)],
		"continuation": Callable(),
	})

# 最終壁接触を最も強く止め、解除後に最終ダメージを確定する。
func _on_wall_contact(wall: Node, _event: Dictionary, impact_position: Vector2) -> void:
	_request_impact({
		"id": &"final_wall",
		"position": impact_position,
		"duration": wall_hold_time,
		"shake": wall_shake_strength,
		"color": wall_color,
		"contact_path": streak_path,
		"hold_path": star_path,
		"aftermath_path": dust_path,
		"effect_scale": 2.2,
		"targets": [boss.sprite, wall.sprite],
		"multipliers": [Vector2(0.84, 1.12), Vector2(0.96, 1.03)],
		"continuation": Callable(wall, "complete_final_impact"),
	})

# 同時要求をQueueへ積み、先行演出がなければ開始する。
func _request_impact(data: Dictionary) -> void:
	if holding:
		pending_impacts.append(data)
		return
	_begin_impact(data)

# 対象を変形し、色付きFXを出して戦闘世界を停止する。
func _begin_impact(data: Dictionary) -> void:
	if stage == null or get_tree() == null:
		_call_continuation(data)
		return
	holding = true
	active_impact_id = data.id
	previous_tree_paused = get_tree().paused
	active_targets.clear()
	_apply_target_squash(data.get("targets", []), data.get("multipliers", []))
	active_contact_fx = _spawn_effect(String(data.get("contact_path", "")), data.position, data.color, float(data.get("effect_scale", 1.25)))
	get_tree().paused = true
	var shake_strength: float = data.get("shake", 0.0)
	if shake_strength > 0.0 and stage.has_method("shake_camera_while_paused"):
		stage.shake_camera_while_paused(shake_strength, float(data.duration))
	impact_started.emit(data.id)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(float(data.duration) * 0.42)
	tween.tween_callback(func():
		if is_instance_valid(active_contact_fx):
			active_contact_fx.texture = load(String(data.get("hold_path", hold_path)))
			active_contact_fx.scale *= 1.08
	)
	tween.tween_interval(float(data.duration) * 0.58)
	tween.tween_callback(func(): _finish_impact(data))

# 変形を戻し、世界再開後に破片と結果処理を始める。
func _finish_impact(data: Dictionary) -> void:
	_restore_targets()
	if is_instance_valid(active_contact_fx):
		active_contact_fx.queue_free()
	active_contact_fx = null
	get_tree().paused = previous_tree_paused
	_spawn_aftermath(String(data.get("aftermath_path", "")), data.position, data.color)
	holding = false
	active_impact_id = &""
	impact_finished.emit(data.id)
	_call_continuation(data)
	if not pending_impacts.is_empty():
		var next_impact: Dictionary = pending_impacts.pop_front()
		call_deferred("_begin_impact", next_impact)

# 対象Spriteへ一瞬のSquashを適用する。
func _apply_target_squash(targets: Array, multipliers: Array) -> void:
	for index in mini(targets.size(), multipliers.size()):
		var target := targets[index] as Node2D
		if not is_instance_valid(target):
			continue
		active_targets.append({"node": target, "scale": target.scale})
		target.scale *= multipliers[index] as Vector2

# 全対象を接触前のscaleへ戻す。
func _restore_targets() -> void:
	for entry in active_targets:
		var target: Node2D = entry.node
		if is_instance_valid(target):
			target.scale = entry.scale
	active_targets.clear()

# 指定素材を接触位置へ表示する。
func _spawn_effect(path: String, world_position: Vector2, color: Color, effect_scale: float) -> Sprite2D:
	if path.is_empty() or stage == null:
		return null
	var effect := Sprite2D.new()
	effect.texture = load(path)
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.modulate = color
	effect.scale = Vector2.ONE * effect_scale
	effect.z_index = 90
	effect.add_to_group("boss_impact_fx")
	stage.add_child(effect)
	effect.global_position = world_position
	return effect

# 停止解除後に粉塵または破片を短く広げる。
func _spawn_aftermath(path: String, world_position: Vector2, color: Color) -> void:
	if path.is_empty():
		return
	var effect := _spawn_effect(path, world_position, color, 0.9)
	if effect == null:
		return
	var tween := stage.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2.ONE * 1.45, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "position:y", effect.position.y - 8.0, 0.28)
	tween.tween_property(effect, "modulate:a", 0.0, 0.28)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)

# 登録されている結果処理を呼ぶ。
func _call_continuation(data: Dictionary) -> void:
	var continuation: Callable = data.get("continuation", Callable())
	if continuation.is_valid():
		continuation.call()

# Scene破棄時にpauseと変形を残さない。
func _exit_tree() -> void:
	if holding and get_tree() != null:
		_restore_targets()
		get_tree().paused = previous_tree_paused
