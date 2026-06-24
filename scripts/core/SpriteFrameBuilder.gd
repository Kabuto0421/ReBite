# 2026-06-13: フォルダ内画像からアニメーションを組み立てる。
class_name SpriteFrameBuilder
extends RefCounted

static func from_folder(folder_path: String, animation_name: StringName, fps: float, loop: bool, file_prefix: String = "") -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)

	for path in _sorted_pngs(folder_path, file_prefix):
		frames.add_frame(animation_name, _load_texture(path))

	return frames

static func add_animation(frames: SpriteFrames, folder_path: String, animation_name: StringName, fps: float, loop: bool, file_prefix: String = "") -> void:
	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)

	for path in _sorted_pngs(folder_path, file_prefix):
		frames.add_frame(animation_name, _load_texture(path))

static func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

static func _sorted_pngs(folder_path: String, file_prefix: String = "") -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Missing sprite folder: %s" % folder_path)
		return paths

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and (file_prefix.is_empty() or file_name.begins_with(file_prefix)):
			paths.append(folder_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths
