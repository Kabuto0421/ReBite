# 突進獣ボスステージ 実装指示書

## 目的

既存のReBiteシステムを利用し、ボスが記憶した攻撃方向を噛みによって再演させ、環境へ攻撃させるボス戦を実装する。

このステージでは、通常攻撃でボスを倒せてはならない。プレイヤーが「現在の自分を狙う攻撃」と「保存方向へ行う再演」の違いを利用した場合のみ勝利できるようにする。

## 前提

- 行動種別と左右方向を記憶できる
- 噛むと記憶行動を保存方向へ再演できる
- DASHとSMASHは既に実装されている
- 歩行、待機、振り向きでは記憶を上書きしない
- 再演時は主人公を狙い直さない

既存のReBiteコアルールは変更しない。

## ボス仕様

- ボス：大型の猪
- HP：5
- 使用攻撃：DASH、SMASH
- 主人公の通常攻撃ではダメージを受けない
- ボスの攻撃は主人公へ通常どおりダメージを与える
- 環境ダメージは噛みによる再演が成立した場合のみ発生する

### DASH

- 遠距離で使用する
- 予備動作後、主人公の方向へ直進する
- 突進開始後は方向転換しない
- ジャンプで回避できる

### SMASH

- 近距離で使用する
- 正面攻撃と短い衝撃波を発生させる
- 後退またはジャンプで回避できる

両攻撃は、予備動作だけで種類と方向を判別できるようにする。

## ステージ進行

ステージは以下の状態で管理する。

1. `Intro`
2. `TeachSmash`
3. `TeachDash`
4. `RockRecovery`
5. `FinalCharge`
6. `Clear`

ボスAIの基本ルールはフェーズによって変更しない。ステージ側が使用可能な仕掛けと演出だけを切り替える。

## ダメージ手順

### 1. 落石

- 保存方向のSMASHで支柱を破壊する
- ボスが落下地点にいれば岩が命中し、1ダメージ
- 外れた岩は床へ残す

### 2. 時限落石

- 天井装置を作動させ、着弾地点を表示する
- 保存方向のDASHでボスを着弾地点へ移動させる
- 岩が命中すれば1ダメージ
- 外れた岩は床へ残す

### 3～4. ストッパー

- 床の岩をSMASHで固定穴へ入れる
- 岩によって大型ストッパーを固定する
- 保存方向のDASHでボスをストッパーへ激突させる
- 成功時に1ダメージを与え、使用した岩の状態を1段階進める

### 5. 最終壁

- 4ダメージ後にボスの頭部装甲を破壊する
- 保存方向のDASHで外壁へ激突させる
- 5ダメージ目としてボスを撃破する

## 岩のルール

岩は自由物理ではなく、固定スロット間で移動させる。

| 状態 | 残り使用回数 |
|---|---:|
| 無傷 | 2 |
| 亀裂 | 1 |
| 破壊 | 0 |

- 初回の落石または時限落石が命中した場合も、使用回数を1消費する
- 空振り、移動、誤った方向の再演では使用回数を消費しない
- 岩の状態が進行する場合は、必ず同時にボスへ1ダメージを与える
- 2個の岩で合計4ダメージを保証する
- 岩同士は重ならず、部屋外へ出ず、消失しない

## イントロ

- 長さは4秒以内
- 初回のみ強制表示し、2回目以降はスキップ可能
- DASH、SMASH、左右方向の記憶、ボス名を提示する
- 最後に記憶タグをボスへ吸収させて戦闘を開始する
- ボス名とDASH／SMASHの文字はゲーム側のフォントで表示する

使用素材：

- `outputs/gimmick-sprites/`
- `outputs/boss-intro-sprites/`
- `outputs/boss-intro-sprites/intro_timeline.json`

## 詰み防止

- 初回の落石と時限落石を両方外してもクリア可能にする
- 誤操作では岩の耐久を減らさない
- すべての岩位置から必要なスロットへ戻せるようにする
- 主人公は岩とボスを飛び越えられる経路を持つ
- DASHとSMASHは全フェーズで再取得可能にする
- プレイヤー死亡時は部屋全体を初期状態へ戻す

## 合格条件

- 噛みを禁止するとクリアできない
- 通常攻撃の誘発だけでは環境ダメージが発生しない
- DASHとSMASHの回避方法が異なる
- 初回罠を両方失敗しても5ダメージを与えられる
- 岩の配置による勝利不能状態が発生しない
- イントロを含め、初見の戦闘時間が3分程度に収まる
- 戦闘後、プレイヤーが噛む必要性を説明できる

## 実装方針

ボス本体の行動と、ボス戦全体の進行は別のStateMachineで管理する。

- `BossStateMachine`：ボスの移動、攻撃、硬直、被弾、死亡を管理する
- `EncounterStateMachine`：イントロ、仕掛けの解禁、最終フェーズ、クリアを管理する

ステージ進行、岩、罠は状態ごとに分離し、管理クラスだけが実際の遷移を行う。各Stateとギミックは直接遷移せず、遷移要求またはイベントを通知する。

まず正攻法と両罠失敗ルートを実装し、その後に演出と難易度調整を追加する。

## 再利用可能なクラス構成

### ボス共通クラス

| クラス | 責務 |
|---|---|
| `BossActor` | ボス本体。移動、アニメーション、当たり判定、HPコンポーネントを保持する |
| `BossStateMachine` | 現在のBossStateを保持し、実際の遷移を行う |
| `BossState` | 各行動Stateの共通インターフェース |
| `BossBrain` | 距離や状況から次の通常行動を選び、遷移を要求する |
| `BossActionRegistry` | `action_id`から実行する攻撃Stateを取得する小さなルーター |
| `BossMemoryComponent` | 最後に確定した行動種別と方向を保存する |
| `ReBiteReceiver` | 噛みを受け、保存済み行動の再演要求を作る |
| `BossHealth` | HP、被ダメージ、死亡通知を管理する |
| `BossDamagePolicy` | どのDamageEventを有効とするか判定する |

`BossBrain`は攻撃を直接実行しない。必ず`BossStateMachine`へ遷移を要求する。

### 攻撃データ

すべての攻撃要求は、次のデータへ統一する。

```text
BossActionRequest
  action_id
  direction
  source        // NATURAL または REBITE_REPLAY
  target_position
  payload
```

- 通常攻撃は`BossBrain`が生成する
- 再演攻撃は`ReBiteReceiver`が生成する
- 攻撃方向が確定した時点で`BossMemoryComponent`を更新する
- `source == REBITE_REPLAY`の攻撃では記憶を更新しない
- 攻撃Stateは通常と再演で共用し、方向と発生源だけをContextから受け取る

これにより、再演専用のDASHやSMASHを別実装せずに済む。

### ボス戦共通クラス

| クラス | 責務 |
|---|---|
| `BossEncounterController` | ボス戦全体の開始、リセット、終了を管理する |
| `EncounterStateMachine` | EncounterState間の実際の遷移を行う |
| `EncounterState` | ボス戦フェーズの共通インターフェース |
| `EncounterConfig` | HP、使用攻撃、イントロ、フェーズ順などの設定データ |
| `EncounterResetter` | ボス、岩、罠、カメラを初期状態へ戻す |
| `EncounterCameraController` | ボス部屋のカメラ固定と解除を行う |

`EncounterState`はボスAIを直接操作しない。使用可能なギミック、演出、次フェーズ条件だけを管理する。

### ギミック共通クラス

| クラス | 責務 |
|---|---|
| `BossGimmick` | 起動、停止、リセット、結果通知を持つ共通インターフェース |
| `ReplayDamageResolver` | 再演攻撃による環境ダメージかを検証する |
| `FixedSlotNetwork` | 岩が移動できる固定スロットと占有状態を管理する |
| `RockActor` | 岩の耐久、現在スロット、表示状態を保持する |
| `FallingRockTrap` | 支柱破壊と落石を管理する |
| `TimedDropTrap` | 警告、カウントダウン、落下、結果判定を管理する |
| `StopperTrap` | ストッパーの展開、固定、衝突、リセットを管理する |
| `FinalWall` | 最終フェーズでの壁激突と撃破を管理する |

## BossStateの分け方

猪ボスでは以下のStateを使用する。

| State | 内容 |
|---|---|
| `BossIdleState` | 待機し、次の行動判断を待つ |
| `BossChaseState` | 中距離で主人公を追跡する |
| `DashTelegraphState` | DASHの方向を確定し、予備動作を再生する |
| `DashExecuteState` | 保存された方向へ直進する |
| `SmashTelegraphState` | SMASHの方向を確定し、予備動作を再生する |
| `SmashExecuteState` | 正面攻撃と衝撃波を発生させる |
| `AttackRecoveryState` | 攻撃後の硬直を管理する |
| `BossStaggerState` | 環境ダメージ後のよろめきを管理する |
| `BossDeadState` | 撃破演出と操作停止を行う |

基本遷移は次のとおり。

```text
Idle ⇄ Chase
Idle / Chase → Telegraph → Execute → Recovery → Chase
Execute → Stagger → Chase
任意のState → Dead
```

予備動作と実行を分けることで、方向確定、記憶更新、回避受付、攻撃判定の開始時点を明確にする。

新しいボスで単純な攻撃を追加する場合は、共通の`TelegraphState`と`AttackRecoveryState`をデータ駆動で再利用する。特殊な移動や複数段階攻撃だけ専用Stateを追加する。

## EncounterStateの分け方

猪ボス専用のEncounterStateは以下とする。

| State | 有効な仕掛け | 遷移条件 |
|---|---|---|
| `IntroState` | イントロ演出 | 演出終了またはスキップ |
| `TeachSmashState` | 落石支柱 | 落石の命中または失敗確定 |
| `TeachDashState` | 時限落石装置 | 時限落石の命中または失敗確定 |
| `RockRecoveryState` | 岩、固定穴、ストッパー | 累計4ダメージ |
| `FinalChargeState` | 最終壁 | 壁激突またはボス死亡 |
| `ClearState` | 勝利演出、出口 | ステージ終了 |
| `ResetState` | なし | 初期化完了 |

```text
Intro → TeachSmash → TeachDash → RockRecovery → FinalCharge → Clear
  ↑
  └──────────── Reset ← PlayerDeath（Clear以外の任意State）
```

各Stateは次のStateを直接生成しない。`request_transition(next_state_id, payload)`を通知し、`EncounterStateMachine`が遷移を実行する。

## ギミック内部の状態

小規模な状態はクラスを増やさず、enumとデータで管理してよい。

```text
FallingRockTrap
  ARMED → FALLING → RESOLVED_HIT / RESOLVED_MISS → SPENT

TimedDropTrap
  DORMANT → COUNTDOWN → FALLING → RESOLVED_HIT / RESOLVED_MISS → SPENT

StopperTrap
  FOLDED → UPRIGHT → LOCKED → IMPACT → FOLDED / DISABLED

RockActor.condition
  INTACT → CRACKED → BROKEN

FinalWall
  INACTIVE → EXPOSED → BROKEN
```

岩の耐久状態と位置は分離する。

```text
RockActor
  condition    // INTACT、CRACKED、BROKEN
  current_slot // 固定スロットID
```

## イベント

クラス間の連携には次のイベントを使用する。

```text
action_committed(action_request)
action_finished(action_request)
memory_updated(memory_data)
replay_requested(action_request)
trap_resolved(trap_id, hit, rock_id)
environment_damage_requested(damage_event)
boss_hp_changed(current_hp)
boss_defeated()
rock_condition_changed(rock_id, condition)
encounter_transition_requested(state_id, payload)
```

ギミックが`BossHealth`を直接変更しない。`ReplayDamageResolver`へDamageEventを送り、再演中であることと重複ダメージがないことを確認してから適用する。

## ディレクトリ例

```text
boss/
  core/
    BossActor
    BossStateMachine
    BossState
    BossBrain
    BossActionRequest
    BossMemoryComponent
    ReBiteReceiver
    BossHealth
    BossDamagePolicy
  states/
    BossIdleState
    BossChaseState
    AttackRecoveryState
    BossStaggerState
    BossDeadState

encounter/
  core/
    BossEncounterController
    EncounterStateMachine
    EncounterState
    EncounterConfig
    BossGimmick
    ReplayDamageResolver
    FixedSlotNetwork
  boar/
    states/
      IntroState
      TeachSmashState
      TeachDashState
      RockRecoveryState
      FinalChargeState
      ClearState
    boss_states/
      DashTelegraphState
      DashExecuteState
      SmashTelegraphState
      SmashExecuteState
    gimmicks/
      FallingRockTrap
      TimedDropTrap
      StopperTrap
      FinalWall
      RockActor
```

## 別のボス戦を追加する手順

1. `EncounterConfig`へHP、攻撃、イントロ、使用ギミックを設定する
2. 既存Stateで表現できない攻撃だけ専用BossStateを追加する
3. ボス戦固有のEncounterStateと遷移条件を定義する
4. 既存の`BossGimmick`を組み合わせ、不足する仕掛けだけ追加する
5. 正攻法、全失敗ルート、リセットをテストする

ボスごとに`BossActor`、記憶、噛み再演、HP、リセット処理を作り直さない。差分は攻撃State、EncounterState、Config、固有ギミックへ限定する。

## 最低限の自動テスト

- 再演攻撃が記憶を上書きしない
- 通常攻撃による環境ダメージが無効になる
- 攻撃方向が予備動作開始後に変化しない
- 初回罠を両方外しても残り岩耐久が4になる
- 岩の耐久減少とボスダメージが必ず同時に発生する
- 4ダメージ未満では最終壁が無効になる
- プレイヤー死亡後に全Stateとギミックが初期状態へ戻る
