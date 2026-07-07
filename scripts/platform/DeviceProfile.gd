# 2026-07-07: 実行環境に応じたUI切り替え判定を提供する。
class_name DeviceProfile
extends RefCounted

# スマホ向け操作UIを出すべき環境かを返す。
static func should_use_mobile_controls() -> bool:
	return OS.has_feature("web_android") \
		or OS.has_feature("web_ios") \
		or OS.has_feature("mobile") \
		or DisplayServer.is_touchscreen_available()

# キーボード前提のK表示ではなく、タッチ用噛みアイコンを使うべきかを返す。
static func should_use_touch_bite_hint() -> bool:
	return should_use_mobile_controls()
