ReBite modular gate rig v7 smooth gate
======================================

今回直した本当の問題
--------------------
フレームの順番ではなく、Gate生成時のY座標が途中で逆戻りしていた。
そのため、半開きから少し閉じて、また開くように見えていた。

今回はGateの位置を次の明示的な20値で再生成した。

[15, 15, 15, 15, 10, 4, -2, -8, -15, -22, -29, -29, -29, -22, -15, -8, -2, 4, 10, 15]

開く区間:
- 5〜11フレーム

開放保持:
- 12〜13フレーム

閉じる区間:
- 14〜20フレーム

Godot配置
---------
aligned版:
- Gate.position = Vector2.ZERO
- Base.position = Vector2.ZERO
- Switch.position = Vector2.ZERO

描画順:
- Gate.z_index = 0
- Base.z_index = 1
- Switch.z_index = 2

Fullはこの3レイヤーから再生成している。
差分最大: 0 px
