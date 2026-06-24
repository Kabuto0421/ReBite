# 2026-06-13: 記憶タグへ飛びつく噛み実行状態。
extends "res://scripts/core/State.gd"

@export var out_time := 0.14
@export var bite_hold_time := 0.08
@export var return_time := 0.16

var target: Node
var committed_record: Resource
var lunge_tween: Tween
var replay_triggered := false

# K入力時に固定された対象へ飛びつき、未固定時だけ従来探索へ戻す。
func enter(payload: Variant = null) -> void:
	var bite_context: Dictionary = payload if payload is Dictionary else {}
	target = bite_context.get("target")
	committed_record = bite_context.get("record") as Resource
	replay_triggered = bool(bite_context.get("replay_started", false))
	if not is_instance_valid(target):
		target = owner_node.pick_bite_target()
		committed_record = target.bite_commit_record() if target != null and target.has_method("bite_commit_record") else null
	if target == null:
		owner_node.bite_missed.emit()
		transition_requested.emit(&"BiteRecover", null)
		return
	if committed_record == null and target.has_method("bite_commit_record"):
		committed_record = target.bite_commit_record()

	owner_node.set_bite_invulnerable(true)
	owner_node.velocity = Vector2.ZERO
	owner_node.play_animation(&"bite")
	owner_node.bite_hit.emit(target)

	var start_position: Vector2 = owner_node.global_position
	var bite_position := _target_bite_position(target)
	lunge_tween = owner_node.create_tween()
	lunge_tween.set_trans(Tween.TRANS_QUART)
	lunge_tween.set_ease(Tween.EASE_OUT)
	lunge_tween.tween_property(owner_node, "global_position", bite_position, out_time)
	lunge_tween.tween_callback(Callable(self, "_trigger_replay"))
	lunge_tween.tween_interval(bite_hold_time)
	lunge_tween.tween_property(owner_node, "global_position", start_position, return_time)
	lunge_tween.tween_callback(Callable(self, "_finish_lunge"))

func exit() -> void:
	if lunge_tween != null and lunge_tween.is_valid():
		lunge_tween.kill()
	lunge_tween = null
	owner_node.set_bite_invulnerable(false)

func physics_update(_delta: float) -> void:
	owner_node.velocity = Vector2.ZERO

func _target_bite_position(target_node: Node) -> Vector2:
	var tag_position: Vector2 = target_node.global_position
	if target_node.has_method("memory_tag_global_position"):
		tag_position = target_node.memory_tag_global_position()
	return tag_position + Vector2(-18.0 * owner_node.facing, 16.0)

func _trigger_replay() -> void:
	if is_instance_valid(target):
		owner_node.bite_contact.emit(target)
	if replay_triggered:
		if is_instance_valid(target) and owner_node.has_method("grant_contact_immunity"):
			owner_node.grant_contact_immunity(target)
		return
	replay_triggered = true
	if not is_instance_valid(target):
		return
	if target.has_method("receive_committed_bite"):
		target.receive_committed_bite(owner_node, committed_record)
	elif target.has_method("receive_bite"):
		target.receive_bite(owner_node)

func _finish_lunge() -> void:
	owner_node.set_bite_invulnerable(false)
	transition_requested.emit(&"BiteRecover", null)
