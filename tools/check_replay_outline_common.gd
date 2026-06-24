# 2026-06-24: 全MemoryEnemyが個体専用の紫再演輪郭を共有できることを確認する。
extends SceneTree

const BossActionRequestScript := preload("res://scripts/boss/core/BossActionRequest.gd")
const ENEMY_SCENES := [
	"res://entities/SkullMonster.tscn",
	"res://entities/HopMonster.tscn",
	"res://entities/boar_monster.tscn",
	"res://entities/BossBoar.tscn",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var materials: Array[ShaderMaterial] = []
	for scene_path in ENEMY_SCENES:
		var container := Node2D.new()
		root.add_child(container)
		var enemy: Node = load(scene_path).instantiate()
		container.add_child(enemy)
		await process_frame
		await physics_frame
		var material := enemy.sprite.material as ShaderMaterial
		assert(material != null)
		for previous in materials:
			assert(material != previous)
		materials.append(material)
		var normal_color := material.get_shader_parameter("outline_color") as Color
		var normal_size := float(material.get_shader_parameter("outline_size"))
		var normal_tint := material.get_shader_parameter("tint_color") as Color
		enemy.set_replay_outline_active(true)
		assert((material.get_shader_parameter("outline_color") as Color).is_equal_approx(enemy.replay_outline_color))
		assert(is_equal_approx(float(material.get_shader_parameter("outline_size")), enemy.replay_outline_size))
		assert((material.get_shader_parameter("tint_color") as Color).is_equal_approx(Color.WHITE))
		if enemy is BoarMonster or enemy is BossBoar:
			assert(enemy.replay_outline_size >= 3.5)
		enemy.set_replay_outline_active(false)
		assert((material.get_shader_parameter("outline_color") as Color).is_equal_approx(normal_color))
		assert(is_equal_approx(float(material.get_shader_parameter("outline_size")), normal_size))
		assert((material.get_shader_parameter("tint_color") as Color).is_equal_approx(normal_tint))
		if enemy is BossBoar:
			var replay := BossActionRequestScript.new(&"dash", Vector2.LEFT, &"REBITE_REPLAY", enemy.global_position)
			enemy.state_machine.change_state(&"Replay", replay)
			assert((material.get_shader_parameter("outline_color") as Color).is_equal_approx(enemy.replay_outline_color))
			enemy.finish_attack(replay)
			assert((material.get_shader_parameter("outline_color") as Color).is_equal_approx(normal_color))
		root.remove_child(container)
		container.queue_free()
		await process_frame

	print("REPLAY_OUTLINE_COMMON_CHECK_OK")
	quit(0)
