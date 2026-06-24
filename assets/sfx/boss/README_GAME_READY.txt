ReBite 実装用・最終マスタリングSE

形式
- WAV / 44,100 Hz / Mono / 16-bit PCM
- DCオフセット除去済み
- 低域不要成分をハイパス処理済み
- 先頭・末尾の不要無音をトリミング済み
- 軽いコンプレッションとソフトクリップ済み
- 最大ピーク: 約 -1.0 dBFS

推奨Godot設定
- Import > Loop Mode: Disabled
- Force Mono: Onのままで可
- BGMとは別のSFXバスへ割り当てる
- まずAudioStreamPlayerのVolume dBを0 dBで試し、ゲーム全体側でSFXバスを調整

収録ファイル
01_boar_dash.wav
  軽快な跳躍DASH。短い踏み切り、低い上昇音、獣の唸り。
  長さ: 0.580秒 / RMS: -18.0 dBFS / Peak: -11.2 dBFS
02_boar_smash.wav
  短い溜めからの重量SMASH。低域衝撃、破砕、破片。
  長さ: 1.020秒 / RMS: -17.0 dBFS / Peak: -7.3 dBFS
03_boar_damage.wav
  鈍い二重打撃、低い苦鳴、短い反動。
  長さ: 0.560秒 / RMS: -18.5 dBFS / Peak: -10.5 dBFS
04_boar_defeat.wav
  致命打、短い咆哮、断片化して消える消滅音。
  長さ: 1.950秒 / RMS: -19.0 dBFS / Peak: -8.8 dBFS
05_boar_wall_impact.wav
  巨体の壁激突、壁の亀裂、苦鳴、粉塵余韻。
  長さ: 0.965秒 / RMS: -17.0 dBFS / Peak: -6.3 dBFS
06_falling_object_warning.wav
  汎用的な大型落下物の危険予告。接近する低振動と中低域の移動ノイズ。着地なし。
  長さ: 1.050秒 / RMS: -21.0 dBFS / Peak: -14.4 dBFS
07_falling_object_and_impact.wav
  汎用的な大型落下物。接近音から重い着地、広帯域の破裂、残響までを一体化。
  長さ: 1.682秒 / RMS: -19.0 dBFS / Peak: -9.9 dBFS
08_falling_object_impact_only.wav
  汎用落下物の着地衝撃だけを分離した版。予告音と別々に再生可能。
  長さ: 0.620秒 / RMS: -17.5 dBFS / Peak: -8.0 dBFS

岩／落下物SEの使い分け
- 06_falling_object_warning.wav:
  落下開始または落下地点の予告時に再生。着地音を含まない。
- 07_falling_object_and_impact.wav:
  短い演出で、落下から着地までを一つの音で済ませる場合に使用。
- 08_falling_object_impact_only.wav:
  06と組み合わせて、実際の接地フレームで再生する。

実装上の推奨
- パズル上の危険予告には 06 + 08 の分割方式が最も同期を合わせやすい。
- 07は落下時間が毎回ほぼ同じ演出用。
- 壁激突はDASH音と重ねず、接触フレームで05だけを強く鳴らすと輪郭が明確になる。