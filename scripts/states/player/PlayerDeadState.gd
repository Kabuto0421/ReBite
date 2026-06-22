# 2026-06-13: プレイヤー死亡時の停止と復帰処理。
extends "res://scripts/core/State.gd"

@export var death_time := 0.95
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = death_time
	owner_node.velocity = Vector2.ZERO
	owner_node.bite_area.set_deferred("monitoring", false)
	owner_node.bite_area.set_deferred("monitorable", false)
	owner_node.drop_bite_area.set_deferred("monitoring", false)
	owner_node.drop_bite_area.set_deferred("monitorable", false)
	owner_node.spawn_death_burst()
	owner_node.play_death_animation()

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.reset_to_spawn()
