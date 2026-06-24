# 2026-06-13: 噛み開始時点で成功予約されることを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage1.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player = scene.get_node("Player")
	var skull = scene.get_node("SkullMonster")
	skull.commit_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(3)

	player.global_position = skull.global_position + Vector2(58, 0)
	player.velocity = Vector2.ZERO
	player.facing = -1
	player.sprite.flip_h = true
	player.bite_area.position.x = -34.0
	await _settle_frames(2)
	assert(player.pick_bite_target() == skull)

	skull.state_machine.change_state(&"RightDash", null)
	assert(skull.is_biteable())
	var bite_context: Dictionary = player.prepare_bite_context()
	assert(bite_context.get("replay_started", false))
	var bite_events: Array[StringName] = []
	player.bite_hit.connect(func(_target: Node): bite_events.append(&"hit"))
	player.bite_contact.connect(func(_target: Node): bite_events.append(&"contact"))
	player.state_machine.change_state(&"BiteLunge", bite_context)
	assert(player.current_state_name() == &"BiteLunge")
	assert(skull.current_state_name() == &"Recalled")
	assert(skull.state_machine.current_state.record.direction.x < 0.0)
	assert(bite_events == [&"hit"])
	await _settle_seconds(0.16)
	assert(bite_events == [&"hit", &"contact"])

	print("BITE_COMMIT_ON_START_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
