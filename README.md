# Memory Bite

敵が直前に実行した行動を「記憶タグ」として噛み砕き、その行動を再演させてステージを攻略するGodot 4製の2Dアクションゲームです。

現在はStage 1からStage 10までのプロトタイプを収録しています。DASH、JUMP、SMASH、落石、連結破壊ブロック、移動足場、ゴール型ステージ、3ヒット制Boarボスなどを実装しています。

## Requirements

- Godot 4.6以降

## Run

Godotでこのリポジトリの `project.godot` を開き、プロジェクトを実行してください。

macOSでGodot.appを使用する場合:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

メインシーンは `res://stage/Stage1.tscn` です。個別ステージを確認する場合は、Godot Editorで対象の `stage/Stage*.tscn` を開いてシーンを実行してください。

## Controls

- 移動: `A` / `D` または左右矢印
- ジャンプ: `Space`
- 記憶タグを噛む: `K`
- ステージをリプレイ: `R`

## Core Mechanic

1. 敵がDASH、JUMP、SMASHなどの自律行動を実行します。
2. 最後に実行した行動が敵の頭上へ記憶タグとして表示されます。
3. プレイヤーが受付時間内にタグを噛むと、その行動が同じ強さで再演されます。
4. 再演行動を使って敵を針へ送る、床を壊す、岩を動かす、足場を上昇させるなどして目標を達成します。

## Architecture

- `scripts/core/StateMachine.gd`: 状態登録と遷移を管理
- `scripts/entities/MemoryEnemy.gd`: 記憶を持つ敵の共通基盤
- `scripts/stage/StageBase.gd`: ステージ初期化と各コンポーネントの橋渡し
- `scripts/stage/StageHud.gd`: 開始命令、目標進捗、クリア表示
- `scripts/stage/ActionBreakGroup.gd`: 行動によって連結破壊される地形
- `scripts/stage/Rockfall.gd`: DASH/SMASHや坂の加速で動く落石

プレイヤー、SkullMonster、HopMonster、BoarMonster、BossBoarはそれぞれStateMachineを持ち、行動単位のStateへ処理を分離しています。

## Validation

主な自動確認スクリプトは `tools/check_*.gd` にあります。例:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/check_stage10_boss.gd
```

## Third-Party Asset Credits

以下の第三者素材を使用しています。各素材のライセンスは素材自体に適用されます。

| 使用箇所 | 素材 | 作者 | ライセンス | 配布元 | 本プロジェクトでの加工 |
|---|---|---|---|---|---|
| Player / Cute Monster | Cute Monster Sprite Sheet | dogchicken | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [OpenGameArt](https://opengameart.org/content/cute-monster-sprite-sheet) | フレーム抽出、透過PNG化、ゲーム内スケール調整 |
| SkullMonster | Skull Monster Sprite Sheet | dogchicken | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [OpenGameArt](https://opengameart.org/content/skull-monster-sprite-sheet) | フレーム抽出、透過PNG化、ゲーム内アウトライン・スケール調整 |
| HopMonster | Flying Tongue Monster Sprite Sheet | dogchicken | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [OpenGameArt](https://opengameart.org/content/flying-tongue-monster-sprite-sheet) | GIFフレーム抽出、背景色の透過処理、ゲーム内アウトライン・スケール調整 |
| ステージ床・壁・針 | 2D Dungeon Platformer Tileset [16x16] | RottingPixels | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | [OpenGameArt](https://opengameart.org/content/2d-dungeon-platformer-tileset-16x16) | タイル切り出し、反復配置、当たり判定への利用 |

CC BY 3.0素材の著作権は作者dogchickenに帰属します。本READMEの作者名、ライセンス、配布元URLを削除せずに利用してください。

## Project-Owned and Generated Assets

以下は上記の第三者フリー素材とは別区分です。

- `assets/sfx/`: プロジェクト所有者が制作・提供した効果音
- `assets/bgm/`: このプロジェクト向けにローカル生成したオリジナルの8bit風BGM。第三者音源サンプルは未使用
- `assets/enemies/boar/`: プロジェクト所有者から提供されたBoarアニメーション素材
- `assets/props/rockfall/`: プロジェクト所有者から提供された落石画像をゲーム用に加工
- `assets/ui/`、`assets/guidance/`、`assets/tiles/cracked_breakable_tile.png`: このプロジェクト向けに生成・加工したUIおよびギミック画像
- ゲームコード、ステージ構成、シェーダー、プロシージャルVFX: 本プロジェクト内で制作

これらの素材には第三者フリー素材のライセンスを適用していません。

## License

第三者素材には上記の個別ライセンスが適用されます。その他のコードおよび素材については、明示的なライセンスが付与されていない限り、権利者の許可なく再利用・再配布できません。
