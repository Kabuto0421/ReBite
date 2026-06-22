# 2026-06-22: 3回の致命判定に耐える大型Boarボス。
class_name BossBoar
extends "res://scripts/entities/BoarMonster.gd"

signal boss_health_changed(current_hits: int, max_hits: int) # 残り耐久が変化した時に通知する。

@export_range(1, 10, 1) var max_hits := 3 # 撃破に必要な致命判定の回数。

var current_hits := 3 # 現在残っている耐久値。
var _base_sprite_scale := Vector2.ONE # 針ヒット姿勢から戻す通常スプライト倍率。
var _base_sprite_rotation := 0.0 # 針ヒット姿勢から戻す通常スプライト角度。

# 通常Boarを初期化し、ボス耐久と基準姿勢を保存する。
func _ready() -> void:
	super()
	current_hits = max_hits
	_base_sprite_scale = sprite.scale
	_base_sprite_rotation = sprite.rotation

# 致命判定を耐久ダメージへ変換し、最後の一撃だけ死亡状態へ進める。
func die() -> void:
	if current_state_name() in [&"BossHit", &"Dying"]:
		return
	current_hits = maxi(0, current_hits - 1)
	boss_health_changed.emit(current_hits, max_hits)
	if current_hits <= 0:
		super.die()
		return
	state_machine.change_state(&"BossHit", null)

# 次の致命判定で本当に死亡するか返す。
func will_die_from_next_hit() -> bool:
	return current_hits <= 1

# 針ヒット演出で変形したスプライトを通常姿勢へ戻す。
func restore_boss_sprite_transform() -> void:
	sprite.scale = _base_sprite_scale
	sprite.rotation = _base_sprite_rotation

# リプレイ時に耐久値も初期化する。
func reset_to_spawn() -> void:
	current_hits = max_hits
	boss_health_changed.emit(current_hits, max_hits)
	restore_boss_sprite_transform()
	super.reset_to_spawn()
