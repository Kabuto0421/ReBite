# 2026-06-13: 針ヒット時の破片とフラッシュを生成する。
class_name SpikeImpactPresenter
extends Node

var stage: Node

func setup(owner_stage: Node) -> void:
	stage = owner_stage

func spawn_burst(impact_position: Vector2) -> void:
	_spawn_flash(impact_position)
	_spawn_rays(impact_position)
	_spawn_shards(impact_position)

func _spawn_flash(impact_position: Vector2) -> void:
	var flash := Polygon2D.new()
	flash.name = "SpikeImpactFlash"
	flash.color = Color(1.0, 0.95, 0.62, 0.88)
	flash.polygon = PackedVector2Array([
		Vector2(0, -64),
		Vector2(24, -18),
		Vector2(88, 0),
		Vector2(24, 18),
		Vector2(0, 64),
		Vector2(-24, 18),
		Vector2(-88, 0),
		Vector2(-24, -18),
	])
	flash.position = impact_position + Vector2(0, -20)
	flash.z_index = 18
	flash.add_to_group("spike_impact_flash")
	stage.add_child(flash)

	var tween: Tween = stage.create_spike_impact_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "scale", Vector2(1.45, 1.45), 0.18)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)

func _spawn_rays(impact_position: Vector2) -> void:
	for i in 16:
		var ray := ColorRect.new()
		ray.name = "SpikeImpactRay"
		ray.color = Color(1.0, randf_range(0.45, 0.85), randf_range(0.08, 0.18), 0.95)
		ray.size = Vector2(randf_range(42.0, 92.0), randf_range(3.0, 6.0))
		ray.pivot_offset = Vector2.ZERO
		ray.position = impact_position + Vector2(randf_range(-8, 8), randf_range(-30, 8))
		ray.rotation = randf_range(-PI, PI)
		ray.z_index = 19
		ray.add_to_group("spike_impact_ray")
		stage.add_child(ray)

		var tween: Tween = stage.create_spike_impact_tween()
		tween.set_trans(Tween.TRANS_QUART)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ray, "scale:x", 0.08, 0.22)
		tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.22)
		tween.tween_callback(ray.queue_free)

func _spawn_shards(impact_position: Vector2) -> void:
	for i in 46:
		var shard := ColorRect.new()
		shard.name = "SpikeImpactShard"
		shard.color = Color(1.0, randf_range(0.20, 0.78), randf_range(0.06, 0.20), 1.0)
		shard.size = Vector2(randf_range(4.0, 11.0), randf_range(4.0, 13.0))
		shard.global_position = impact_position + Vector2(randf_range(-22, 22), randf_range(-42, 10))
		shard.rotation = randf_range(-0.8, 0.8)
		shard.z_index = 17
		shard.add_to_group("spike_impact_shard")
		stage.add_child(shard)

		var outward := Vector2(randf_range(-1.0, 1.0), randf_range(-1.15, 0.35)).normalized()
		if outward == Vector2.ZERO:
			outward = Vector2.UP
		var distance := randf_range(72.0, 190.0)
		var tween: Tween = stage.create_spike_impact_tween()
		tween.set_trans(Tween.TRANS_QUART)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shard, "global_position", shard.global_position + outward * distance, 0.42)
		tween.parallel().tween_property(shard, "rotation", shard.rotation + randf_range(-5.5, 5.5), 0.42)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.42)
		tween.tween_callback(shard.queue_free)
