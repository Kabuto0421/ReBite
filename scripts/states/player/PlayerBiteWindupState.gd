# 2026-06-13: 噛み入力直後の短い溜め状態。
extends "res://scripts/core/State.gd"

@export var windup_time := 0.08
var timer := 0.0
var bite_context: Dictionary # K入力時に固定した対象と記憶。
var handed_to_lunge := false # 無敵状態をBiteLungeへ引き渡したか。

# 固定済み対象を保持して噛み溜めを開始する。
func enter(payload: Variant = null) -> void:
	timer = windup_time
	bite_context = payload if payload is Dictionary else {}
	handed_to_lunge = false
	if bool(bite_context.get("replay_started", false)):
		owner_node.set_bite_invulnerable(true)
	owner_node.velocity.x *= 0.25
	owner_node.play_animation(&"bite")

# BiteLunge以外の理由で中断された場合は噛み無敵を解除する。
func exit() -> void:
	if not handed_to_lunge:
		owner_node.set_bite_invulnerable(false)

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		handed_to_lunge = true
		transition_requested.emit(&"BiteLunge", bite_context)
