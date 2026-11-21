# NEON CITY 2099 ― 詳細仕様書 v1.0

サイバーパンク2077にインスパイアされた、ブラウザで遊べるオープンワールド試作。
Godot 4.6.3 / GDScript で開発し、GitHub Pages で公開、PCとスマートフォン（横画面）の
両方で遊べることを目標とする。

---

## 1. コンセプト

- 舞台は2099年のネオン都市「ネオ・キバラ」。プレイヤーは運び屋「ランナー」として
  街を自由に歩き・走り・車で駆け抜け、仕事（ミッション）をこなして電子マネー
  「エディ（€$）」を稼ぐ。
- 常に夜。雨上がりのような濡れた路面の反射感、ピンク/シアン/イエローのネオン、
  霧とホログラム看板で「サイバーパンクな空気」を作る。
- 本家のような巨大都市や物語性は狙わない。「小さくても、歩いて楽しい・走って
  気持ちいい・仕事がある街」を v1 の完成形とする。

## 2. ワールド

| 項目 | 仕様 |
|---|---|
| 広さ | 約 660m × 660m（11×11 ブロック、道路間隔 60m） |
| 生成 | 起動時にコードで自動生成（シード固定で配置は毎回同じ） |
| 建造物 | 約120棟。高さ 12〜70m。窓はエミッシブ素材で発光 |
| 道路 | アスファルト＋センターライン発光。交差点つき格子状 |
| 歩道 | 道路沿いに一段高い歩道。歩行者NPCが歩く |
| ネオン看板 | ビル壁面に発光サイン（バー/ラーメン/ホテル/クラブ等の文字看板含む） |
| 小物 | 街路灯、自販機風ボックス、ホログラム広告塔（回転） |
| 境界 | 街の外周はバリアで囲い、外に出られない |

## 3. プレイヤー（徒歩）

- 三人称視点。カメラは背後追従、右ドラッグ/マウスで回転、自動で腰〜肩の高さ。
- 移動: WASD / 左スティック。ダッシュ: Shift / DASHボタン（スタミナ無制限）。
- ジャンプ: Space / JUMPボタン。
- インタラクト: F / ACTボタン（車の乗り降り、ミッション受注、端末操作）。
- 体力 HP100。落下ダメージなし。HPが0になると「クローン病院」前にリスポーンし、
  治療費 €$50 を失う（所持金が足りなければ無料）。

## 4. ホバーカー（車両）

- 街に数台駐車された共有ホバーカーに近づいて F で乗車、F で降車。
- 運転: W/S アクセル/ブレーキ・逆進、A/D ステアリング。
  最高速 約 28m/s（約100km/h）。ホバー浮遊で車体が上下に揺れる。
- カメラは車両後方へ自動で引き、速度でFOVが少し広がる。
- 歩行者を轢くと指名手配 +1。建物・他車との衝突は物理で跳ね返る（車両HPなし）。
- チェックポイントレースと配達は車両使用が前提の設計。

## 5. NPC・交通

- 歩行者NPC 約24人: 歩道を往復歩行。色とりどりの服装（コード生成の色違い）。
  車に近づくと横に避ける。会話なし（v1）。
- 交通車両 約10台: 道路を一方通行ループで走行する自動運転カー。
  プレイヤーの車と衝突するが、渋滞や信号の概念はなし。

## 6. ミッション（仕事）

依頼端末（街に点在する発光キオスク）で受注。HUDとミニマップに目的地マーカー表示。
同時に受けられるのは1件まで。3種をランダムローテーション。

| 種類 | 内容 | 報酬 | 備考 |
|---|---|---|---|
| データ回収 | 指定地点でデータチップを拾い、別の地点へ届ける | €$120 | 徒歩/車両どちらでも可 |
| ハッキング | 指定端末で3秒チャンネルして侵入 | €$200 | 完了時に指名手配 +1 |
| チェックポイントレース | 車両で制限時間内に5つのゲートを順に通過 | €$180 + 残り時間ボーナス | 制限時間 90秒 |

- 完了すると即時に報酬が入り、キルフィード風の通知が画面に出る。
- 中断は不可（v1）。レース失敗時はそのまま終了し次の仕事を受けられる。

## 7. 指名手配（警察ドローン）

- 警戒レベル 0〜3（★表示）。犯罪行為で上昇:
  ハッキング完了 +1 / 歩行者を轢く +1（連続では上がらないクールダウンあり）。
- ★1以上で警察ドローンが出現しプレイヤーを追跡。接触で HP 減少（1回 8）。
- ドローンから 90m 以上離れた状態を 8 秒保つと ★ が1つ減る。
- ★3でドローンは最大4機まで増える。ドローンは撃墜不可（v1、逃げる専用）。

## 8. HUD / UI

- 左下: バーチャルスティック（タッチ時）。右側: ACT / JUMP / DASH ボタン。
  車両時は ACT が降車、運転ボタン表示に切替。
- 上部左: HPバー、所持金 €$。上部右: 警戒レベル ★、現在時刻表示（ゲーム内時計）。
- ミニマップ（右上・約170px）: 道路網、プレイヤー、ミッション目的地、
  車両位置、警察ドローン（赤）を表示。
- 画面中央下: インタラクト促し（「F: 乗車」など状況で変化）。
- スタート画面にタイトルと遊び方。ポーズ/設定画面は v1 では無し。
- 日本語フォント（M PLUS 1p）を同梱し、端末フォントに依存しない。

## 9. 操作一覧

| 操作 | PC | スマホ |
|---|---|---|
| 移動 | WASD | 左スティック |
| 視点 | マウス（クリックで捕捉）/ ドラッグ | 右半分ドラッグ |
| ダッシュ | Shift | DASHボタン長押し |
| ジャンプ | Space | JUMPボタン |
| インタラクト | F | ACTボタン |
| 車両 アクセル/ブレーキ | W / S | 右側ペダルボタン |
| 車両 ステアリング | A / D | 左スティック左右 |
| 全体マップ | M | MAPボタン |

## 10. 技術仕様

- エンジン: Godot 4.6.3-stable（GL Compatibility、Web エクスポート、スレッドなし版）。
- キャラクターモデル: CesiumMan（Khronos glTF Sample Models、CC-BY 4.0）を
  CIでダウンロードして使用。リポジトリにはモデル本体を含めない（従来作と同方式）。
- 建物・車両・看板はすべてコード生成メッシュ+マテリアル。外部テクスチャ不使用。
- 物理: キャラクター/車両は CharacterBody3D、建物は StaticBody3D のボックス衝突。
- パフォーマンス目標: Web（iPhone Safari/Brave）で 30fps 前後。
  ドローコール抑制のため建物は共有マテリアル、OmniLight は装飾用に使わず
  エミッシブ表現中心。実ライトは月明かり+プレイヤー周辺のみ。
- タッチ方針: emulate_mouse_from_touch は ON（ボタンがタッチに反応する条件）。
  スティック/視点はタッチindex管理、モバイルではマウスフォールバック無効化
  （Pocket TPS v3.3 の教訓を最初から適用）。
- 公開: GitHub Pages（Actions で Web エクスポートを自動ビルド）。

## 11. v1 に含めないもの（将来候補）

- 武器・戦闘（銃撃戦）、室内エリア、物語/カットシーン、セーブデータ、
  キャラクターカスタマイズ、昼夜サイクル、電車などの公共交通、マルチプレイ。
- 次点候補: 武器と戦闘、配達ミッション追加、車両購入・ガレージ、
  ラジオ（BGM生成）、フォトモード。

## 12. 検証計画

- 起動・都市生成・ミッション受注→完了→報酬、乗車/運転、指名手配の増減を
  ヘッドレス自動テストで確認する。
- Xvfb で実描画スクリーンショット（街並み/運転中/HUD）を確認する。
- 公開後はブラウザで開始までを確認。タッチ操作の最終確認は かいと の iPhone
  実機で行う（デスクトップ確認と分けて報告する）。

---
作成: 2026-11-06 / NEON CITY 2099 v1

## v1.1 見た目強化（2026-11-11）
ゲーム内容は v1 のまま、描画まわりだけを強化:
- 空: 星240個＋月（円盤＋ハロー、ビルボード／フォグ無効マテリアル）
- 遠景: 境界の外に窓明かりタワーのスカイライン（約100棟、うち高層はアンテナ＋
  赤色ビーコン）を追加し「街が続いている」感を出す
- フォグ調整（濃度0.0038、空への影響0.35）＋色調整（彩度1.10／コントラスト1.07）
- 道路: 縁ライン、全交差点に横断歩道（MultiMesh 2,420枚）、水たまり110箇所
  （低粗さ＋金属質で濡れ感）、アスファルト粗さ 0.55→0.34
- 街灯: ポール先端に発光バルブ、路面に加算グラデーションの光だまり
- 建物: 高層（>38m）に屋上アンテナ＋点滅ビーコン（共有マテリアルで同期点滅）
- 車: ヘッドライト／テールライトの前後が逆だったのを修正（前=−Z）。
  スポットライトを前端へ移動し、加算グラデーションの擬似ライトコーンを追加
  （運転中と交通車のみ表示）
- 検証: 専用テスト14項目（新要素の個数・開始・歩行・乗車・加速）全合格、
  Xvfbスクリーンショット5枚で目視確認。Compatibility の制約（グロー無し）内で
  擬似グローに寄せた設計。iPhone 実機の見え方は未確認。

## v1.1.1 実機フィードバック修正（2026-11-11）
かいと の iPhone 実機報告で2件修正:
- **降車できない**: 運転中、ACTボタンとGASボタンが同じ位置に重なっていて
  タッチではGASしか押せなかった。運転中はACTをDASHの位置（右上）へ移動。
- **曲がると前後逆に見える**: 運転カメラのピボット（車の子ノード）に
  heading を二重適用していた。直進時は一致して正常に見えるが、90°で
  カメラが横を向き、180°で車の前方に回って逆向きになっていた（v1からの
  潜在バグ）。ピボットはピッチのみに修正。
- 検証: 専用テスト11項目（方位4方向のカメラ位置、ACTの位置、実経路での
  降車）全合格＋ v1.1テスト14項目も継続合格。旋回後の運転スクショで
  追尾カメラが正常なことを目視確認。

## v1.2 Blenderモデル導入（2026-11-13）
本家2077との差分分析で最大の弱点だった「全パーツが直方体プリミティブ」
を解消するため、主要オブジェクトを Blender 4.5 で造形し GLB 化:
- **ホバーカー**（hover_car.glb）: ウェッジ型面取りボディ（側面プロファイル
  押し出し）、傾斜ガラスキャノピー、前後フル幅ライトバー、リアウイング、
  ホバースラスターポッド＋発光ディスク、サイドスカート/インテーク/
  ディフューザーフィン。全パーツを1メッシュ7サーフェスに統合し、
  BodyPaint サーフェスだけ Godot 側で車体色に差し替える（5色対応維持）。
  GLB が無い環境では従来の Box 造形に自動フォールバック。
- **街の小物**: 自販機（ガラス越しの発光ドリンク列・取り出し口・
  キーパッド・看板）、信号機（アーム＋赤/黄/シアン3灯＋ホロシェブロン）、
  ホロ広告トーテム（両面発光パネル）。歩道ブロックと交差点に配置。
- **ヒーロータワー3種**: 段差スパイア型／双棟スカイブリッジ型／
  ハローリング円筒型を遠景スカイラインに4基配置し、ランドマーク化。
- 旧造形の問題点（差分分析）: 角が全て90°で面取りなし、パネル分割・
  グリーブル（凹凸の生活感）なし、車は箱5個、ビルは窓テクスチャ箱1個、
  遠景は同型箱の拡大コピーでランドマーク不在。
- 配布方式: GLB のバイト列を ModelBlob リソース（.tres、テキスト形式）に
  格納し（assets/model_data/）、実行時に GLTFDocument で復元する。
  復元後、発光（emission）サーフェスは unshaded 化する（model_loader の
  マテリアル修復）。シェーディング付き emission は WebGL/llvmpipe で
  白飛びして色が消えるため、街の他のネオンと同じ unshaded 表現に揃える
  （model_loader.gd）。テキストpush制約と「.b64等の素ファイルは Web の
  pck に入らない」制約を同時に回避でき、CI ワークフローの変更は不要。
  ローカル開発では実 .glb があればそちらを優先。GLB を全て隠した状態で
  v12テスト11項目＋v111テスト11項目が合格することを確認済み。
  （当初案の base64＋CI復元方式は、ワークフロー編集がスマホで困難なため
  本方式に置き換え。assets/models_b64/ は旧案のアーカイブとして残置。）

## v2 (2026-11-13) — people & facades
- **Characters**: Quaternius Ultimate Animated Character Pack (CC0 /
  Quaternius Asset Licence, see `assets/people_q/SOURCE.md`). All share
  the CharacterArmature rig (62 bones) and clips; `people.gd` is the
  registry (`People.spawn`, `People.play` by clip-name suffix, loop
  enforcement). Player = Punk (Idle/Walk/Run state machine in
  `player.gd` + a soft fill light). WomanCasual uses an older
  HumanArmature rig at scale 0.37.
- **Shipping form**: characters are trimmed in Blender
  (`blender/trim_chars.py`: 9 clips kept, keyframes halved) into
  `assets/people_q/opt/`, then wrapped as ModelBlob `.tres` in
  `assets/people_data/` (same route as the props; `ModelLoader` takes
  an optional tres path override). Untrimmed originals and the rejected
  Gobkit candidate set live OUTSIDE the project in
  `~/workspace/asset_library/`.
- **Crowd**: 120 NPCs (80 walking block perimeters, 40 standing with
  Idle/Wave/Clapping clips), centre-biased block choice; animation
  playback distance-culled beyond 55 m (`npc.gd`).
- **Facades**: Blender `facade_kit.glb` (storefront: glass band,
  awning, sign board, AC, pipe) instanced up to 130× on block
  frontages by `city.gd._build_facade_kits`, sign boards tinted per
  instance. Procedural MultiMesh relief (912 instances: ledges, wall
  AC units, corner pipes) + 132 unshaded blade signs with per-instance
  colours (`_build_facade_relief`). Sidewalk material gained a
  procedural noise texture (UV scale 1 only — see the llvmpipe note).
- Tests: `v13_test.gd` (people, 12 items), `v14_test.gd` (facades,
  4 items); all suites pass in GLB and blob modes. Web pck is now
  ~19 MB (people data dominates) — first load is noticeably longer.

## v2.1 (2026-11-13) — playtest fixes (collision / touch / variety / verticality)
- **Collision pass**: facade kits, vending machines, holo totems and
  traffic lights gained StaticBody boxes (`city._add_collider`);
  pedestrians shuffle aside via soft separation in `npc.gd` instead of
  being walked through.
- **Touch look**: `hud.gd` now computes drag deltas from absolute
  positions (per-pointer last position), clamps spikes and applies the
  accumulated delta once per frame — `InputEventScreenDrag.relative`
  got spiky when both thumbs were down, wobbling the camera.
  Verified by `tests/v15_touch.gd` (synthetic multitouch under Xvfb).
- **Building variety**: 10 window-texture styles (palettes, lit ratio,
  window cell size), per-building material tint, setback crowns on
  tall towers, annexes on big mid-rises, rooftop vent boxes + water
  tanks, and district neon palettes (centre mixed / N cool / S warm /
  E magenta / W teal) for trims, kit signs and blade signs.
- **Verticality**: elevated expressway along the central avenue
  (deck y=9.5, centre pillars — traffic lanes at x=±3.3 stay clear,
  underpass light strips, 6 shuttle cars on deck), 7 glass skybridges
  between tall neighbours, 18 silhouette hills on the horizon.
- Tests: `v15_test.gd` (11 items) + `v15_touch.gd` (4 items); all
  earlier suites still pass in GLB and blob modes.

## v2.2 (2026-11-13) — brightness pass
- Sky is now a ProceduralSkyMaterial gradient (indigo zenith, violet
  city-glow horizon) instead of a flat near-black colour; ambient
  0.66→0.88, moon 0.7→0.85, fog colour lifted to indigo, tonemap
  brightness 1.02→1.13 / contrast 1.07→1.03, unlit window base,
  asphalt, sidewalk and ground albedos all raised a step. Night mood
  kept, but walls and streets no longer crush to pure black.

## v2.3 (2026-11-13) — atmosphere & billboards
- Air: fog density 0.0038→0.0072 with a brighter blue-indigo fog
  colour, sky horizon glow lifted, ambient 0.88→1.16, tonemap
  brightness →1.22. Distance now melts into haze instead of black.
- 39 hero billboards on tall towers: procedural video-ad art
  (5 gradient/geometric motifs + scanlines) with brand Label3D
  (TURBO, データ堂, HOTEL-9, …). Puddles 110→200 and larger.
- Storefront kits gained same-colour additive reflection pools;
  two rotating searchlight beams on the tallest towers.

## v2.4 (2026-11-13) — flight + parkour
かいと の要望「空を飛びたい。空飛ぶ車で飛ぶとか、そこから人が降りたら
落ちるモーションやジャンプ、壁を登るパルクール」への対応。
- **飛行**: 車で Rキー / FLYボタン（運転中はJUMPボタンがFLY/LAND表示に
  切替）で飛行モード。自動で前進（巡航 21 m/s）、W/GAS・Spaceで上昇
  11.5 m/s、S/BRK・Shiftで下降 13.5 m/s、旋回でバンク、ピッチで傾く。
  上限 95 m。着地すると自動で飛行解除＋「着陸」トースト。
- **空中降車と落下**: 飛行中にF/ACTで降りるとプレイヤーはそのまま落下
  （落下ポーズ＋脚のサイクル）。落下速度ピークが 16 m/s を超えると
  落下ダメージ（最大55、HPに反映）、13 m/s 超で着地ロール。
  置き去りの車も重力で落下して着地する（屋根の上に落ちた判定あり）。
- **二段ジャンプ**: 空中で1回だけ追加ジャンプ（vy 6.8）、
  その間モデルが1回転するフリップ演出つき。
- **パルクール（壁登り）**: 壁に向かってジャンプすると胸の高さの
  レイ（0.85 m、StaticBodyのみ）で壁をつかんで登攀（3.4 m/s）。
  落下中に壁へ押し込みながら落ちても自動でつかむ。登攀中にジャンプで
  ウォールジャンプ（壁の法線方向へ 5.6＋上 7.6）。頭上のレイが抜けたら
  屋根へマントル（上に跳ねて屋根に立つ）。壁から離れる方向へ押すと降りる。
- **HUD・説明**: スタート画面の操作説明に飛行とパルクールを追加。
  乗車・飛行切替・着陸・落下ダメージはトーストで通知。
- 検証: `tests/v17_test.gd` 13項目全合格（飛行上昇、空中降車→落下→
  ダメージ、置き去り車の落下、二段ジャンプ、壁登り、ウォールジャンプ、
  屋根へのマントル）。テスト側の修正1件：二段ジャンプの1回目を
  テレポート直後（着地判定前）に打つと空中ジャンプとして消費されて
  失敗したため、30フレーム後に遅らせた。既存スイートも全合格
  （v11 14 / v111 11 / v12 13 / v13 12 / v14 4 / v15 11 / v16 4）。
  v15_touch は headless では失敗するが Xvfb では 4/4 合格
  （headless ではタッチ入力が届かないハーネスの制約で、回帰ではない）。
- スクショ: `shots/v17_a_flight.png`（屋根の上を飛ぶ車）、
  `shots/v17_b_fall.png`（空中降車後の落下）、
  `shots/v17_c_roof.png`（マントル後の屋根上、落下ダメージでHP 45%）。
  Web書き出しOK（pck 20,072,220 bytes）。公開pushは未実施
  （承認カードが必要なため、かいと の「pushして」待ち）。

## v2.4 (2026-11-13) — flight & parkour
- Flying cars: FLY button / R toggles flight in any driven car.
  Auto-cruise ~21 m/s, GAS/W (or Space) climbs, BRK/S (or Shift)
  sinks, steering banks the hull; ceiling 95 m. Descending onto a
  street or a roof lands and resumes driving (roofs are drivable).
  Toggling off mid-air or bailing out drops the car with gravity —
  it crash-lands and stays usable. Desktop F now also exits a car.
- Player air kit: double jump (with a front flip), falling pose
  (lean-back + slow leg cycle; the CC0 pack has no fall clip),
  landing roll on hard impacts, fall damage above ~16 m/s impact
  (capped at 55).
- Parkour: jump toward a wall (or fall past one while pushing in)
  to wall-climb at 3.4 m/s; jump while climbing for a wall jump;
  reaching the top mantles onto the roof. Buildings/kits only.
- Roof finish rework: the old solid emissive "trim" slab blew out
  white and hid players' feet; now a dark cap + thin neon cornice
  frame, so rooftops read as rooftops from the air and on foot.

## v2.4.1 (2026-11-13) — flight self-cancel fix
- Bug (iPhone report): tapping FLY never engaged flight. The landing
  check ran from the first frame — a grounded car with no climb
  input read as "just landed" and cancelled flight instantly. The
  headless test had masked it by holding climb from the same tick.
  Fix: landing requires having actually been airborne, plus a 0.6 s
  takeoff assist so the car lifts off on toggle alone.
  Regression: tests/v18_test.gd replays the exact phone sequence
  (toggle with no input → climb → hover → descend → land), 5/5.

## v2.5 (2026-11-13) — flight controls, solid deck, PBR roads, props
- Flight controls reworked (iPhone feedback: no fwd/back buttons,
  car drifted forward on its own): GAS/BRK (W/S) are thrust again,
  release to hover-stop; altitude moved to the left stick's vertical
  axis on touch, Space/Shift on keys. Auto-cruise removed.
- The expressway deck, its barriers/crossbeams and the skybridges
  are solid now — flying cars can land on the deck and drive it.
- Roads: real PBR asphalt (ambientCG "Asphalt 006", CC0: colour /
  normal / roughness) on 847 UV-scale-1 tiles; sidewalks gained
  concrete normal/roughness (ambientCG "Concrete 034", CC0).
  Textures ship as ModelBlob .tres (assets/texture_data) via
  texture_loader.gd, same trick as the models.
- Street props (Quaternius, CC0, via Poly Pizza): benches and trash
  cans on sidewalks, dumpsters at the curb — 115 placed, all with
  colliders. Facades gained grime: speckle, rain streaks, dark
  base/parapet bands in the window texture generator.
- Parked-car fall rework: a bailed-out car now falls until its
  contact is stable (the old height gate froze cars mid-slide on
  low props), then snaps to street height when it lands low.
- Tests: v18 rewritten for the new controls (incl. landing ON the
  deck), v19 (tiles/props/materials) 5/5, all prior suites pass.

## v2.6 (2026-11-13) — free-look car camera, reverse fix, photo towers
- Flight reverse bug (iPhone report "can't go back"): the flight
  thrust line computed throttle * -17 for BRK = full FORWARD. The
  ground branch was correct all along (its REV_SPEED constant is
  signed). Fixed; regression tests/v21 (ground -9, flight -17).
  Found by the new Xvfb touch-path test (tests/v20_touch.gd) that
  replays the phone order through the real joystick/HUD layers;
  descend via stick-down also verified there (plus camera orbit).
- Car camera free-look: driving/flying used a camera rigidly fixed
  behind the car. Look drags (touch + desktop mouse) now orbit the
  car rig (car.add_car_look, yaw/pitch offsets that ease back to
  centre after the drag ends).
- Roads: asphalt colour map desaturated and darkened (~x0.42) with
  a neutral tint — the saturated blue carpet is gone.
- Buildings: 61 towers now use photographic night facades
  (ambientCG Facade 008 / 010 / 018B, CC0, night-baked with a
  highlight soft-clip so lit windows don't blow out) as stacked
  ~13 m segments; the rest keep the procedural neon windows.

## v3 (2026-11-14) — visual overhaul P1–P3 (per the Cyberpunk 2077
## visual-design research: palette discipline, style kits, dusk)
- P2 style kits (Blender, blender/build_kits_v3.py): ONE shared
  1024² atlas (blender/paint_atlas.py: entropism concrete, kitsch
  plastic + round windows, corporate glass, storefront glass, an
  8×3 lit-pane grid, sign art, hazard/shutter/awning/poster/grille
  cells). Kits ship UNTEXURED; Godot re-applies the atlas by glTF
  material name (KitShade shaded / KitGlow unshaded / KitDark /
  KitPlastic / KitYellow). Three towers — tower_ent (concrete,
  AC units, pipes, shutter side door), tower_kit (rounded plastic
  corners, round glow discs, YELLOW roof band), tower_mil (dark
  glass, fins, sparse cool panes, crown light strip, canopy) — all
  with a lit ground-floor storefront band + sign boards. Three
  street modules (shop_a glass+awning, shop_b food stall, shop_c
  shutter+poster) and two blade signs (blade_sign, blade_sign_y).
  133 kit buildings replace ~62% of small procedural buildings
  (district-weighted styles); frontage modules (kits + legacy
  facade kits) now run 2-per-side in the centre — 175 placed.
  UV lesson: Blender's primitive cube uses a NET UV layout (each
  face owns a small tile, not 0..1) — kit UVs are normalised per
  face onto the atlas rect, otherwise faces sample a sliver and
  windows stretch ~2×.
- P1 palette discipline: neon trim/sign materials pulled 15%
  toward white, emission 2.6→2.3; roof cornice neon only on ~35%
  of buildings; wall signs 55%→35%; relief blade signs CLUSTER
  (centre / near junctions 55%, elsewhere 10%) leaving "rest
  walls"; photo-facade towers dimmed ×0.84 into the palette.
  Yellow fingerprint (#FCEE0A family): JOB kiosk screens + labels,
  expressway pillar hazard-stripe bases, first parked car + one
  traffic colour, kitsch roof bands and food-stall signs.
- P3 dusk grade: sky horizon is a warm amber-violet band under an
  indigo zenith; the directional light is a low warm sun
  (1.0, 0.64, 0.44); fog is coloured violet-grey (0.215, 0.16,
  0.225) at 0.0068; saturation 1.12→1.07. Steam: 100 vents of
  stacked billboards at sidewalk edges, tinted ~60% toward the
  district neon, animated in _process. Wet streets: every
  street-facing sign registers a spot; _build_streaks lays up to
  170 additive gradient streaks (MultiMesh) on the road under
  them, coloured like the sign — fake reflections, zero cost.
- Tests: new v23 (kits/shops/steam/streaks/kiosk yellow/dusk
  readback) 12/12 in GLB AND blob modes; v16 updated to the v3
  fog value + mixed-frontage pool check; v11/v13/v14/v15/v17/
  v18/v19/v21/v22 all pass. Portraits: tests/v29_kitshot.gd.

## v4 Phase 1 — Blender-authored terrain (2026-11-15, NOT pushed)
- Direction (かいと, 2026-11-15): the 60 m grid city reads nothing
  like Night City — rebuild the TERRAIN in Blender as one authored
  piece, assemble assets in Godot, mimic the game UI, optimize for
  iPhone 16 Pro. Approved plan: density-first 450 m city; Phase 0
  layout map approved as drawn (design/v4_map.png, v4_layout.md).
- Terrain (blender/build_terrain_v4.py -> assets/terrain/
  terrain_v4.glb, 3,046 faces; ships as ModelBlob .tres): ground
  plates + outer apron, centre plaza 68x68, two diagonal avenues,
  rounded ring road, S canal (water -2.0, 3 bridges) + market
  street, NE terraces +6/+12/+18 with switchback road, curved
  elevated skyway at 10 m deck. Same script exports the layout
  (layout_v4.gd const — loose .json does not ship in web pck):
  164 plots (110 kit buildings), heroes (megabuilding 104x56 h110
  N of plaza, arch building straddling SW avenue, cylinder tower),
  POIs (5 kiosks, clinic, spawn (0,48) facing the megabuilding),
  7 NPC walk blocks, traffic/deck loops, race points, pillars.
- world_v4.gd EXTENDS city.gd and overrides build(): terrain load
  (mats re-applied by name), plot assembly (v3 kits scaled to
  irregular plots incl. 45° avenue plots; procedural/photo towers
  parametric), heroes, POIs, holo, skyline, boundary, routes.
  main.gd preload switched to world_v4; minimap draws road_lines.
- Collision = analytic heightfield (4 m grid over +-232, terrace
  smoothsteps + plaza + canal carve + bridge decks) + deck boxes +
  pillar cylinders in one StaticBody "TerrainBody". LESSON
  (minimal repro, ex-tests/v24_miniprobe.gd): Godot physics
  triangles are front-facing when wound CLOCKWISE seen from the
  outward side — the RH-rule normal must point INWARD (down for
  terrain tops) or rays/bodies pass through. Bank gradient capped
  ~24 deg (BANK_W 20) so cars climb.
- car.gd: ground-follow raycast + slope pitch/roll alignment;
  crash-slowdown only on wall-like normals (was capping climbs);
  traffic runs layout loops via set_traffic_path; deck cars tour
  the skyway loop.
- Optimization pass 1: roof caps + cornice strips -> 2 MultiMeshes
  (MeshInstances 1560 -> 1018 city-wide); skyline -> MultiMesh per
  window material; tower detail (signs/billboards/labels/antennas)
  visibility_range_end 170 m; NPC meshes 85 m; cars 260 m.
  Draw calls (Xvfb): spawn 1284 -> 613, hilltop vista 2785 -> 931,
  top 2843 -> 751. Street target ~350 not yet met — kit LOD is a
  later phase; smoothness verdict is the iPhone's.
- Tests: tests/v24_test.gd 23/23 (terrain, heights probes incl.
  canal floor -2.7 / deck 10.05 / hilltop 18, car terrace climb
  driven through the real HUD input path). Shots: v40_shot.gd
  (top vs approved map, spawn, canal, hills, hilltop). Web export
  OK locally. v3 remains live; v4 pushes only on かいと's word.
- NOT yet ported to v4 (later phases): storefront frontage
  modules, steam, wet streaks, street props, searchlights,
  facade relief; UI mimic (Cyberpunk-style HUD/menus) is its own
  phase per the approved plan.

## v4 Phase 2 — Blender-modelled buildings (2026-11-15, NOT pushed)
- かいと's call: the Phase-1 buildings were still boxes with a
  mosaic-tile window texture; ALL of them are now replaced by
  modelled Blender buildings (his explicit Phase 2 mandate).
- Window textures (blender/paint_windows_v4.py): 6 tileable night
  facades (ent/kit/mil x a/b lit variants), one tile = 4 windows x
  4 floors at a FIXED real size (6.8 x 12.4 m). The generator maps
  wall UVs in metres, so windows are the same size on every face
  of every building — this, not a new texture, is what kills the
  mosaic look. Lit windows carry blinds/silhouettes/mullions.
- Generator (blender/build_buildings_v4.py): 22 archetypes
  (3 styles x low/mid/high + ent/mil towers, a/b seeds), authored
  in Godot coords from a quad accumulator: podium with glass
  storefront band + sign board, shaft with setbacks (2 tiers on
  high, 3 on towers, floor-quantised heights 3.4 + n*3.1), floor
  slab rings, crown slab (+glow strip), rooftop clutter (AC, water
  tank on ent, antennas), style geometry — ENT face AC units +
  corner pipes + shutter, KIT rounded corner columns + balcony
  slabs + disc sign + yellow roof band, MIL vertical fins +
  entrance canopy + vertical sign. Mid/high/tower also emit a
  massing-only *_far.glb for the LOD swap (near <140 m, far >135).
- Heroes rebuilt as models too: hero_mega (3 mil-glass tiers,
  courtyard glow frame, yellow cornice + sign board; the
  "キバラ・ワン" Label3D stays in Godot above the board),
  hero_arch (ent legs/slab + cyan under-glow), hero_cyl (wrapped
  mil drum + balcony rings). Godot colliders unchanged (solid
  boxes / cylinder via _solid()).
- Integration (world_v4.gd): _make_bld_materials (unshaded window
  mats via TextureLoader, texture_repeat is a BOOL in Godot 4.6),
  _apply_bld_mats by glTF material name, _place_building_v4 picks
  the closest-height archetype per plot (stable position hash for
  a/b), local-space collider (fixes the Phase-1 double-scale
  quirk), LOD pair placement. Blobs: assets/bld_data/*.tres (41),
  textures via gen_tex_blobs. _place_kit_v4 removed;
  _add_tower_v4 remains only as a load-failure fallback.
- Verification: v24 23/23 (unchanged contract), new v42 5/5
  (164 model buildings, 93 far LOD twins, 3 hero models).
  Portraits v41 (style row on the plaza: frames/blinds/fins/disc
  sign all read; mosaic gone), street shots v40 re-taken.
  Census: MeshInstance3D 1018 -> 797 (models are single meshes).
  Draw calls (Xvfb): spawn 778 (Phase 1: 613 — real models cost
  ~+27% at street level; still -39% vs the unoptimised v4 build),
  canal 133, hills 524, hilltop 1186. Web export OK locally.
  iPhone smoothness verdict still pending (needs the v4 push,
  which happens only on かいと's word).

## v4 Phase 2.5 — atmosphere & texture finishing (built 2026-11-15, NOT pushed)
Direction from かいと: match the ATMOSPHERE of his CP2077
references (3:52 AM street + daylight street). Core insight: in
Night City the sky is never black (light-polluted pale teal-grey),
buildings are dark masses, and light comes from signs/screens/
lamps — v4 had it inverted (dark sky, uniformly glowing windows).
- Grade (main._build_environment): sky top (0.16,0.24,0.29),
  horizon (0.58,0.52,0.42); ambient cool (0.48,0.56,0.60)x1.02;
  fog blue-grey (0.33,0.39,0.43) density 0.0085, sky_affect 0.75;
  directional cool (0.62,0.72,0.82)x0.55; tonemap 1.12/1.04/1.02.
  world_v4 overrides _build_sky: no stars at dawn, faint moon.
- Window textures repainted (paint_windows_v4 v2): walls darker
  (ent base 104->72, kit 148->100), lit ratios ent ~22% / kit ~26%
  (dimmer tints) / mil ~15%. Buildings read as dark masses.
- Baked per-face shading: generator assigns window materials by
  face (+Z full, +-X "S" x0.74, -Z "B" x0.52; +12 material names,
  Godot tint variants share the texture). Kills the
  four-identical-posters look without light-colour contamination.
- Street light (world_v4._build_atmosphere): 164 additive wet
  streaks at building fronts (district colours), street lamps
  along roads + plaza perimeter/inner (115 total: pole/bulb/pool
  MultiMeshes, warm pools 13m), 28 steam vents (city _steam +
  inherited _process animation; sprites culled at 95m), 6 gantry
  sign bridges across avenues + NS main (billboard board, brand
  Label3D both sides, under-glow strip, post colliders, culled
  260m). Terrain albedos raised (dawn streets are mid-grey).
- Mega face: 27x11.5 ad screen + pink/cyan vertical sign strips
  + plaza light pool on the spawn-facing front.
- Caught in review: lamp poles used CylinderMesh defaults
  (r=0.5!) — giant black pillars; fixed to r=0.09/0.12.
- Tests: v24 23/23, v42 5/5, v43 6/6 (new: streaks/lamps/steam/
  gantries). Draws (Xvfb): spawn 985 (atmosphere costs ~+200 vs
  Phase 2), hilltop 1531. Web export OK. iPhone smoothness and
  the brightness verdict remain かいと's on a v4 push.

## v4 Phase 2.6 — the density finish (built 2026-11-15, NOT pushed)
かいと: 「あなたからみて完璧だと思う？あなたの完璧を見てみたい」 —
the polish pass by my own standard. What the reference has that a
clean model city lacks: signs jutting at every height, junk on
every roof, wires across every street.
- 154 blade/flat signs on building fronts (_build_blade_signs_v4;
  MultiMesh per material, culled 175 m) + additive glow pools
  under ~45% of them.
- 265 rooftop props (_build_rooftops_v4): AC clusters, antennas
  with pulsing beacons (_mat_beacon), water tanks, billboard
  pylons on tall buildings — jagged silhouettes vs the pale sky.
- 140 cable segments (_build_cables_v4): sagging two-segment
  spans across avenues/streets every ~38 m + plaza diagonals.
- Mega screen spill: 3 cyan streaks across the plaza; holo
  retinted pink -> pale cyan (ring + label) for palette discipline.
- Tests: v24 23/23, v42 5/5, v43 6/6, v44 5/5 (signs/props/cables).
  Draws: spawn 1000, street framings 545-653, hilltop 1531.
  Web export OK. Remaining honest ceiling on mobile web: true
  reflections/volumetrics, AAA model density, character fidelity.

## v4 Phase 2.7 — PBR ground (built 2026-11-15, NOT pushed)
かいと's pick: the ground was ツルツル (flat colour). Full PBR
sets from ambientCG (CC0), every shipped map connected:
- Roads + skyway deck: Asphalt006 (Color/NormalGL/Roughness/AO/
  Displacement), 4 m tiles.
- Plaza + sidewalks + canal walls: Concrete034 (Color/NormalGL/
  Roughness/Displacement — this set ships no AO map), 5-6 m tiles.
- City floor (GroundMat): Asphalt008, heavily cracked, full set
  incl. AO, 5 m tiles.
Wiring (world_v4._pbr_ground): StandardMaterial3D with albedo,
normal (0.7-1.0), roughness texture, AO (light affect 0.55),
Displacement as parallax heightmap (0.5-1.0). The terrain mesh
has no usable UVs -> world-space TRIPLANAR (uv1_triplanar);
verified clean on this VM's llvmpipe first (tests/tri_test.gd —
the v1-era uv1_scale corruption does NOT reproduce on the
triplanar path). Textures ride as TextureLoader blobs (24 total).
Blend work: the sets' native colours are blue-grey and read
bright blue under the cool dawn ambient — tints rebalanced to
warm dark greys (R>=G>B, ~0.46-0.60) so the ground sits in the
same grade as the buildings; verified in spawn + market shots.
Draws unchanged (spawn 1000). All suites pass; Web export OK.

## v4.1 (2026-11-15, from his iPhone photos)
- **Fall-out fixed**: probe raycasts found the only collision hole was the
  perimeter trench (heightfield ended at ±232, walls at ±235). Heightfield
  now spans ±244, boundary walls run y −13..137, and `main._rescue_fallout()`
  returns the player (and a driven car) to the clinic if y < −8 ever happens.
- **Light pools tamed for the device** (Xvfb reads dimmer than the iPhone):
  lamp pools 0.30→0.16, sign pools 0.20→0.11, mega pool 0.34→0.15, streaks ×0.36.
- **PlazaDisc**: the holo plinth shipped with pale LineMat and read as a white
  ellipse (photo 4's UFO) — now a dark metal base via a name override.
- **Searchlights removed** in v4 (tilted additive cones read as geometry
  errors); world_v4 overrides `_build_searchlights()` to a no-op.
- **NPCs**: standing spots are random along the block perimeter (corners
  stacked NPCs into each other), walkers start mid-edge (no lockstep
  overlap), standing NPCs gently separate at runtime.
- **Banks**: terrace embankments got their own BankMat — cracked PBR at
  3.5 m tiles with a stronger normal, instead of sharing the canal concrete.
- **Skyline**: dark silhouette clones of the window materials + dimmer,
  rarer cornices (the pastel ring clashed with the modelled city).

## v4.2 UI (2026-11-15, overnight)
- **CpUi kit** (`cpui.gd`): Cyberpunk-2077 UI language rasterised into
  StyleBoxTextures — 45° chamfered corners (signature diagonal pair),
  near-black ink fills, cyan #00f0ff / red #ff003c / yellow #fcee0a /
  icy #e0f7ff palette, red accent segment on panel top edges.
- **Touch buttons**: chamfered dark panels, cyan rims (ACT = yellow, the
  primary action), pressed state floods the rim colour, 0.92 press pop.
- **HP bar**: segmented (10 pips) chamfered bar, floods red below 30 HP;
  value in the label ("HP 87"). Money/clock in Rajdhani.
- **Title panel**: chamfered ink panel, red Rajdhani logo, yellow
  chamfered start button; enlarged to 600×448 so the help text fits.
- **Minimap/big map**: near-black blue, cyan road lines, yellow diamond
  kiosks, red diamond objective, cyan-outlined player arrow, red tick.
- **Joystick**: dark disc, cyan rings, red diagonal ticks; feel pass —
  0.12 deadzone + 1.35 power curve on the stick output.
- **Fonts**: Rajdhani Bold (OFL) ships in a ModelBlob .tres like the
  models (font_loader.gd); used for Latin/digits, M PLUS 1p keeps
  Japanese. Rajdhani is the recognised stand-in for the game's
  Blender Pro UI typeface.
- **Look feel**: player and car cameras ease toward input targets
  (20/s and 16/s) instead of snapping — weight without lag.

## v4.3 — device-photo PDCA (2026-11-15 overnight, his 02:38 photos)
His new device photos showed: the plinth now read as a BLACK hole,
the headlight cone as a solid white teardrop (worst in flight), car
underglow as a hard cyan ellipse, lamp pools still disc-like, and
the aerial view flat/empty. Fixes, verified over two Xvfb PDCA
cycles (tests/v48_shot.gd):
- Cone: peak alpha 0.22→0.075, falloff pow 2.2, shorter (6.5 m,
  r 1.2); hidden while flying (per-frame visibility rule in car
  physics). SpotLight 2.2→1.6; underglow Omni 0.7→0.4, range 3.4.
- Plinth: PlazaDisc takes the plaza concrete PBR; added a cyan
  torus ring + dark plate + inner ring + 6 bollard lights
  (_build_plinth_v4).
- Pools: new _soft_pool_texture (pow-3 falloff) for lamp and sign
  pools; lamp pools 13 m→10.5 m, alpha 0.16→0.13.
- Plaza dressing: painted ground markings (additive JPG
  plaza_marks: rings, spokes, ticks, corner hazards, worn),
  8 benches (concrete), 4 planters.
- Air traffic: 3 lanes × 3 AVs (dark hull, cyan window strip, red
  tail, additive trail) animated in world_v4._process — the sky
  is alive from the ground and from the air.
- Suites: v15/v18/v20/v21/v24/v42/v43/v44/v45 all green; Web
  export OK.

## v5 — buildings rework (2026-11-15 overnight, his 02:51 order)
"Buildings are the one thing I'm not satisfied with" — full
Blender-side rework, two portrait PDCA cycles (tests/v49_bldshot):
- Massing forms (silhouette variety): stack / cant (offset tiers
  on stepped corbels) / step (staircase slices) / slope (wedge
  roof prism) / twin (two slabs + recessed core + lit skybridges).
  22 → 32 archetypes (kit gains towers).
- Ground floors are individual shop units: glass panes split by
  fins, per-unit sign strips, shuttered units, and BldGlassLit —
  warm lit interiors so storefronts read as open businesses.
- Window textures v3: recess shading, rain drips under sills,
  closed blinds / drawn AC units / curtains on dark panes, TV
  glow + brightness jitter on lit panes, concrete panel seams
  (ent), curtain-wall mullion grid (mil), kit frames darkened.
- Facade geometry: ent duct trunking + patch panels, kit
  alternating balconies with railings + vertical colour stripes,
  mil spandrel bands + glass sky-lobbies.
- Roofs: parapet rims on every archetype, helipads on towers.
- Perf guard: near-LOD swap 140 m → 125 m (fog hides the pop);
  near face counts 358-519, far 47-63.
- Suites v24/v42/v43/v44/v45 green; Web export OK.

## v5.1 — landing / roll hardening (2026-11-15, his device report)
His iPhone photos after jumps showed the legs left in extreme poses
(his crops: feet rotated flat like paddles; the Run cycle's measured
extremes are Foot 2.17 rad / knee 1.73 rad). Desktop repro (stationary
jump, double jump, 26 m fall, frame-by-frame roll sequence) did NOT
reproduce a stuck pose — the state machine tested clean — so the
landing transition family was hardened instead:
- Landing now ends any flip and zeroes the model pitch on the spot
  (a flip could previously keep rotating on the ground, and a
  completed flip left rotation.x at -TAU, which the pitch lerp then
  unwound as a whole extra turn).
- The landing roll was cut at 0.5 s of a 1.67 s clip (45%) and the
  clip was force-looped by People.play. Roll is now a true one-shot
  (People.play gains an oneshot flag + clip_length helper) and
  _roll_t matches the clip: 1.67 s / 2.0 speed = 0.83 s.
- Verified: roll sequence re-shot (full arc, clean stand), suites
  v15/v18/v20/v21/v24/v42/v45 green (touch suites under Xvfb).
  Device confirmation still pending — if it persists, the deciding
  detail is whether it follows plain jumps or only flips/high falls.

## v5.2 — ROOT CAUSE of the broken legs (2026-11-16)
His follow-up ("breaks after WALKING too") killed the jump theories.
Real cause, found by forcing the web build's load path locally: the
repo carries no .glb files, so the live build loads characters via
ModelLoader's ModelBlob route (runtime GLTFDocument), while local
tests used the editor-imported .glb. The RUNTIME importer drops bone
tracks whose pose is constant in a clip (its Idle has NO Foot tracks;
Walk 27/60 tracks) — the editor importer emits 1-key tracks instead.
A bone a clip does not drive keeps the previous clip's pose: after
any walk/run, the feet stayed frozen at gait extremes (measured on
the blob path: Foot.R 2.2 rad while idling; editor path: 0.0).
Fix: ModelLoader._complete_bone_tracks() — on the blob route only,
every animation gains a rest-pose key for every bone track it lacks
(the editor importer's behaviour). Verified on the blob path (Punk
.glb hidden): after run+jump+stop, Foot.L/R = 0.0 at idle (was
0.12/2.2); gait extremes unchanged while running. NPCs share the
route, so the whole cast is repaired at once. v5.1's landing/roll
hardening stays (independent, harmless).

## v5.3 roads & car feel (2026-11-16, his report: roads incomplete, car feels off)
- Diagnosis (tests/v51_cardrive.gd photos): terraces are smooth bare mounds with roads painted on; dashes stopped at the canal banks; the skyway's underside was cracked lot; the car's slope target came from a single raycast normal that steps at every heightfield triangle seam.
- Car: slope target now derived from 4 height probes at the wheel positions (heights are continuous across seams; normal fallback when a probe misses). Off-road bog: grounded tilt > 0.30 rad (banks, not the flattened road ribbons at <= ~0.15 rad) scales drive target down to a 7 m/s crawl — verified: bank leg max speed exactly 7.0, road leg unaffected (tests/v52_numbers.gd).
- Roadworks (world_v4._build_roadworks_v53, layout-driven, visual only): retaining walls + pale caps wherever a road edge drops > 1.1 m (wall plane at the edge, foot sampled 6.5 m out so the exposed face reads tall); center dashes across the 3 canal bridges (ns/e/w); asphalt apron + dashes under the skyway deck.
- Bridge integrity probed (tests/v52_bridgeprobe.gd): heightfield and physics hold 0.16 across all spans. An apparent "car stops at the bridge" in early numbers runs was a test-harness artifact (teleport-drop + render-frame timing leaving the car unsettled at the 16 cm bridge step); a settled drive crosses at full speed (tests/v52_bridgedrive.gd).
- Known remainder: the terrace LANDSCAPE is still smooth mounds — a true fix reshapes the height profile (stepped benches) in BOTH blender/build_terrain_v4.py and _height_smooth_gd in sync; proposed as v5.4, not bundled here.
- Suites: v45 6/6, v24 23/23, v18, v21, v42 5/5 headless; v15 4/4, v20 6/6 under Xvfb. Device confirmation pending (tilt feel, bog feel, wall read).

## v5.4 shops, more jobs, pedestrian bridge (2026-11-16, his asks: もっと仕事 / 薬が買いたい / 店の中 / 歩道橋と階段)
- Shops (world_v4._build_shops, data in SHOP_DEFS): 6 storefronts — 薬局ヒール堂 (plaza E), コンビニ ネオンマート (plaza W), 麺屋サイバー + カフェ ドリップ (market street), 電脳店デンキバ (plaza S), ブティック 2099 (east street). Each has a street panel (door + neon sign) and a full interior room 40 m below the same xz (minimap stays truthful): shelves/products or cafe tables by kind, counter + a clerk (Quaternius cast, Idle), ceiling lights + one warm omni, buy displays, exit door. main.gd: in_shop state, door/buy/exit via the ACT chain, fall-rescue exempt while inside, camera spring shortened to 1.7 indoors.
- Items: medkit €$80/+60HP, drink €$30/+25, onigiri €$15/+15, ramen €$50/+40, coffee €$20/+10. Bought at in-shop displays; used with H or the HUD ITEM button (appears when carrying, uses the strongest). Verified end-to-end in tests/v54_test.gd.
- Jobs 3 -> 6 kinds: courier (pick up at a shop counter inside, deliver to a street spot, €$150), errand (buy a medkit at the pharmacy, deliver to a kiosk, €$260; owning one skips the buy), rooftop (reach a terrace-top marker, €$180).
- Pedestrian bridge (world_v4._build_footbridge): over the canal at x=-60, deck at +3.2 m, ramped stairs both ends (step visuals over walkable ramp slopes), glowing railings, lamps, 歩道橋 sign. Junction lesson: ramp ends must terminate exactly at the span edge at span height — a 14 cm lip or an overlap under the span both wedge the walking capsule (probed in tests/v54_bridgeprobe.gd; crossing verified in v54_test).
- Note: on the llvmpipe check pipeline the bridge's top faces blow out white at grazing angles (also true of ordinary roads); top-down and device-class rendering are dark asphalt (v54_topdown.png).
- Suites: v54 13/13 (shops/jobs/bridge), v24 24/24 (canal probe moved off the bridge + a footbridge-deck assertion), v45/v18/v21/v42 green, v15/v20 touch green. Device confirmation pending.

## v5.5 AAA-look pass + Sketchfab assets + new protagonist (2026-11-17, his order: AAAタイトルのような見た目に / 全部朝までに)
- Diff list first (design/v55_diff.md): 12 gaps vs real CP2077 stills, fixed in impact order. Before/after shots: tests/v55_shots.gd (street/plaza/market/terrace/aerial).
- Lighting/atmosphere (main._build_environment): sky darkened to deep teal (top 0.07,0.12,0.18), ambient energy 1.02 -> 0.68 with a cooler colour, fog deep teal (0.15,0.21,0.26) with sky_affect 0.45, moon energy up 0.55 -> 0.78, grade contrast 1.14 / saturation 1.12. Judged on photos over 3 iterations (first pass too navy). Wet roads: world_v4._pbr_ground rough_mult — roads 0.55, deck 0.6, ground 0.92 (defined moon specular streak).
- Glow: probe test proved Environment glow works on this Compatibility pipeline (not blown out); shipped modest (intensity 0.55, strength 0.9, bloom 0.08) because devices render brights hotter and fullscreen passes cost fps. One-line revert if the iPhone chokes.
- Sketchfab models (all CC BY except the hovercar CC BY-SA; credits on the title panel): cleaned in Blender (blender/clean_sketchfab.py — bake world transforms, drop material-less meshes, decimate, cap textures) and shipped via the ModelBlob route (assets/skf_data/*.tres). Placed as heroes with claimed plots (world_v4._build_heroes_v55): SKY T 021 (-52,-140), Revolving Tower (146,-24, darkened to graphite 0.40 — the raw model is a white sculpture), Background Apartment (-84,152 — moved off the footbridge ramp after v54 caught the overlap), IQINSO Hotel (-186,104), Milk & Peach (58,130, colourful face to the market street). Props: noodle vending + 2 vending machines. Cars: car.gd MODEL_VARIANTS alternates the Lionsharp hovercar and Boberemn sci-fi car by spawn order; air traffic AVs now use Mitya Petrov's Flying Car #2 (box fallback kept).
- NOT extracted: golukumar's "Cyberpunk City" (his pick) — a single merged scene (1.26M tris, material-chunk meshes, 12 shared 5.7K/8K atlases); no clean single building is extractable at sane cost. Needs a dedicated session if wanted.
- Protagonist swap (his pick): "Cyberpunk character" by 4d_Bob (CC BY), rig 56 bones in cm. Punk's Idle/Walk/Run/Roll retargeted in Blender (blender/retarget.py): world-delta transfer with (a) frame conjugation F between the rigs' armature spaces (Punk's pose space is pre-Root-rotation, ~87 deg off), and (b) rest-pose matching — Punk's T-pose arms were pre-posed into the target's A-pose (~53 deg) before sampling the source rest, otherwise the arm deltas over-rotate past vertical (legs were unaffected: both rigs rest with legs down). Pipeline traps found: FBX "A-pose" NLA track blends over baked clips (removed pre-bake); skinning the bone-parented glasses/eyes makes the glTF exporter recurse forever (they already follow head_05 via bone parenting — left alone); a parentless Icosphere at the origin is a modelling leftover (dropped); edit-bone spans read at half scale on this import (height measured from pose-bone rest translations). Clips verified frame-wise in Godot (tests/v55_char.gd): idle/walk/run/roll all read correctly, feet included. Player spawn: People CAST "Cyber" (people.gd), player.gd spawn("Cyber"). The 9 MB GLB ships as 4 split ModelBlob parts (assets/skf_data/cyberpunk_character_p0..p3.tres, ~3.0 MB each — a single tres would be ~12 MB, over the GitHub push body limit; ~7.7 MB per push also 413s, ~3.0 MB passes): ModelLoader.load_model_parts concatenates them back into the same blob route.
- Deliberately NOT done tonight: terrace stepped-bench terrain reshape (own version: Blender terrain regen + _height_smooth_gd sync + collision retest), real shadows/reflections (engine/perf ceiling on the target phones).
- Suites: v55 5/5 (both import routes), v54 13/13, v24 24/24, v42, v45, v21, v18 headless; v15 4/4, v20 6/6 under Xvfb. Device confirmation pending (grade darkness, glow cost, new hero feel).

## v5.6 terraces become benches + road markings + 2K ground + living sky (2026-11-17, his order: プロと同じやり方で / グラフィック・テクスチャ・道路・雰囲気をすごいゲームに)
- Terrace reshape (the v5.3 remainder, plan in design/v56_terrace_plan.md): the height profile in blender/build_terrain_v4.py and world_v4._height_smooth_gd changed IN SYNC — both now use a bench profile (1 m flat lip, then a smoothstep riser over 3.5 m, BANK_W 4.5) instead of the 20 m smoothstep that read as dirt mounds. Verified identical: the Blender side dumps 626 samples (V56_DUMP=1) and tests/v56_test.gd compares the GDScript port on every sample (worst diff 0.0044) plus 7 hand-computed profile properties.
- Road-corridor exception: the two climbing roads (ave_a_ne + the switchbacks) keep the legacy 20 m ramp profile inside an 11 m half-width corridor, blended to benches by 18 m (corridor distance from the same polylines on both sides of the sync). Without it the bench risers would cliff-cut the climbs and the v5.3 bog rule would stall cars. v24's terrace-climb drive test still passes (car reaches the 12 m-top kiosk).
- Collision: the analytic 4 m grid skips cells fully inside the terrace quadrant and a 2 m fine patch covers exactly that region; the seam lies on flat height-0 ground, so no cracks (v45 hole scan clean; total ~44k tris).
- Terrain mesh details (all baked into the GLB by build_terrain_v4.py): terrace cap lips (WallMat band across each edge, +0.03 lift, reads as a concrete rim in photos); continuous edge lines on every DASH_ROADS road (0.14 m LineMat ribbons at ±(w/2−0.45), heights sampled off the centreline so they hug the climbs); 7 zebra crossings (plaza N/S, market E/W, ave_b_se junction, both diagonal avenues); ~180 manhole discs (ApronMat octagons at ±22% width offsets). Layout unchanged (plot generation still uses the legacy 20 m bank exclusion — layout_v4.json/.gd byte-identical, city does not reshuffle).
- Ground textures 1K -> 2K: ambientCG Asphalt006 / Asphalt008 / Concrete034 re-downloaded as 2K-JPG (NormalGL), re-encoded for the push body limit (colour/rough q82, normal q78 — tres sizes 0.27–2.61 MB). AO/disp stay 1K. Shipped via the texture blob route as before.
- Atmosphere: aviation beacons — one shared unshaded material + shared sphere instanced on every placed building >= 55 m (cap 20), pulsed in world_v4._process (2.6 s period, sharp k² flash, all towers in sync, international style). The mega ad screen got a dedicated material whose tint slowly hue-rotates (it previously shared the cycling billboard palette).
- Verification trap found en route: Godot's import cache for the terrain GLB went stale (Nov 15 .scn) — local shots silently rendered the OLD terrain while collision already used the new heights. Fixed by deleting .godot/imported/terrain_v4.glb-* and re-importing; a mesh probe (tests/v56_probe.gd) now asserts the zebra corner verts exist in the loaded mesh. CI is unaffected (clean checkout import). Rule: after regenerating any GLB, check the imported .scn mtime or probe the mesh.
- Photo PDCA (tests/v56_shots.gd, v56_shots2.gd, v56b_shot.gd): benches read as constructed terraces with pale cap rims, edge lines trace the whole road net incl. the climbs, zebras + manholes read at street level, 2K cracked asphalt is crisp in the foreground. Suites: v56 (626-sample sync + profile), v45, v24, v42, v54 fails=0, v55 5/5, v18, v21 headless; v15/v20 touch under Xvfb. Device confirmation pending.

## v5.7 — traffic & roads fix (2026-11-17)
His iPhone verdict on v5.6 (7 photos): traffic cars wedge between
buildings, ignore roads and roam the central plaza; raised roads
show "plates" and float where no plate; white lines look unreal.
- Traffic rewritten as pure pursuit on LEFT-HAND lanes (ring centre
  line offset 3.4 m to the left of travel, both directions). The old
  any-collision waypoint-skip (the plaza-crossing cascade) is gone.
  Car-following (match leader speed, ~5.5 m gap), curve slowdown,
  ground probe hover (static-only raycast, spawn snap from +16),
  bounded waypoint advance, lateral leash (street 10 m / deck 6 m)
  and a cruise-based stuck detector (2.5 s window — judging by
  current speed never fires on a car held at a dead stop; that was
  the deck U-turn nose-to-nose deadlock).
- Pre-existing bug found: deck traffic NEVER moved — main.gd set
  the typed Array[Vector3] via set("_loop", …), which silently
  fails; deck cars now go through set_traffic_path() + the
  "deck_traffic" group. Parked car at (5,0.55,100) sat inside the
  ring junction; moved to (4.5,0.55,126).
- Corridor set unified: {ave_a_ne, switch, ring, e_st, h1_e} built
  from LayoutV4 road names in BOTH the Blender builder and the
  runtime height function (v5.6 had left the ring's NE arc and two
  streets crossing 60° bench risers).
- Roads: ribbons subdivide at 2.5 m and drape EVERY corner on the
  height function; terrace top plates + bench rings replaced by a
  draped 3 m ground grid over the terrace quadrant (BankMat where a
  cell's height range > 1.0, else GroundMat) — visual surface ==
  collision function. Markings: 44 junction discs suppress dashes
  and edge lines inside junctions/plaza; LineMat is now a shaded
  paint (albedo 0.62 grey, faint 0.35 emission) instead of unshaded
  laser white; plaza medallion dimmed to (0.34,0.35,0.38).
- Verified: v57 traffic sim ALL PASS (120 s × 14 cars: path
  1079–1681 m each, max lateral 5.19 street / 4.57 deck — the
  street worst is a momentary ~5 m swing on the SW arc's outer
  lane, car centre ~1.6 m past the paint edge at road height;
  min pair distance 6.52; no plaza entry; no car stuck ≥20 s),
  v56 height-sync (626 samples, worst 0.0044), v45/v24/v42/v54/
  v55/v18/v21 headless, v15/v20 Xvfb touch, 6 PDCA photos (deck
  cars seen driving the skyway; zebras + suppressed junction
  markings; draped switchback with no plates).

## v5.8 — buried NPCs fix (2026-11-17)
His iPhone photo: two NPCs waist-deep in a terrace bank slope.
Cause: the v5.7 draped ground grid sampled the height function on
a 3 m lattice while the collision patch uses 2 m — on the bench
risers (up to 6 m over a 3.5 m run) the two surfaces deviated by
up to ~1 m, and characters stand on the collision, so they sank
into the visual slope (or floated). Fix: the grid now uses the
collision patch's EXACT lattice (x 44..244, z -244..-52, 2 m) and
its exact triangulation — cells are emitted as explicit triangles
(a,b,c) + (a,c,d) via add_tri, because a quad handed to the
exporter picks its own diagonal. Verified by tests/v58_probe.gd
on the blob route: all 9,797 lattice points present in the mesh,
worst height deviation 0.0003 m at authored points. (Godot's glTF
import shifts vertices a few mm in XZ; on the steepest riser that
still reads as up to ~3 cm — ankle level, accepted.) Player photos
on the 6 m and 18 m risers (tests/v58_shots.gd) show feet flush
with the slope. Terrain faces 11,083 -> 26,125; tres 3.0 MB.
- Second half of the same bug (found by re-checking after the
  report): NPCs are scripted Node3D, not physics bodies, and
  walked at their block's single flat y (npc.gd). On the NE
  terrace block (150,-136, y=12) the switch-road corridor keeps
  the smooth ramp and the ground rises to ~14.2 m at the block's
  edge — NPCs there sank up to ~2.2 m regardless of the grid.
  npc.gd now samples _terrain_height every frame (via main.city),
  scoped to the terrace quadrant where visual == collision;
  outside blocks keep the flat y. Verified by
  tests/v58_npc_test.gd: 12 test NPCs on the two terrace blocks,
  60 sim-seconds, 1,392 samples, worst |y - terrain| = 0.0.

## v5.9 — graphics pass (2026-11-18)
His verdict: the game looks like a 20-year-old retro title, not
CP2077; buildings and roads need more work. Diagnosis (verified
in code): no shadows at all, 512px flat window textures with no
normal maps, almost no facade relief, no backdrop skyline.
- Moon shadows ON: directional_shadow_max_distance 90, bias
  0.06 / normal bias 1.2 / blur 1.2 (main.gd, moon only; the
  v5.5 grade is untouched). Biggest single gain: buildings and
  props now sit ON the ground. Draw calls at spawn 1090 -> 2632
  including the shadow pass; llvmpipe frame time +70% is a CPU
  renderer artifact — iPhone fps is his call, 1-line revert.
- Window textures repainted at 1024 (real-size mapping kept:
  6.8 x 12.4 m tile): frames, mullions, blinds, interior
  silhouettes, sill grime; a height map is painted alongside
  and converted (Sobel, wrap-safe) to win_*_n.jpg normals.
  Facade materials are now SHADED with normals wired (they
  were unshaded by design; albedo x1.3 compensates the light
  response — environment values unchanged).
- Facade greebles: 312 AC units (with fan discs) + drain pipes
  as 3 MultiMesh draw calls.
- Backdrop skyline: 51 silhouette towers at 380-650 m with
  real-size window grids, fog-faded, no collision/shadows.
- Ground: 16 grime blotches + 43 glossy puddles on flat road
  stretches and the plaza (subtle by design).
- Verified: Xvfb PDCA v59a (before) -> v59e (after) + blob-route
  closeups (v59h), probe counts, v45 PASS, v57 PASS (traffic
  120 s). v56 not re-run (terrain height fn untouched; its
  samples file was lost in a VM restart).

## v6.0 — CASINO NEON PEARL (2026-11-21, his ask: Okada Manila-style casino, real games)
Plan: design/casino_plan.md (Phases 1-3 built; Phase 4 balance pass
and Phase 5 publish are separate). The casino is a 7th shop_sites
entry (kind "casino") on the plaza south row, door at (28, 35.5);
the interior floor (88 x 58 m) floats at y=-60 under the plaza.
- Facade: the plot behind the frontage is a kit tower whose own
  shopfront modules reach z~33.8, so the gold front is built as a
  portico ~2 m proud of that face (cheeks + canopy close the gap);
  pink neon strips, CASINO NEON PEARL sign, red carpet, bollards.
- Interior: entrance + 2 detector gates + guards, information desk,
  main cashier cage (Blender cage model), BJ x6 + roulette x2 pit
  with pit-boss podium, glass poker room (1 playable + 1 decorative
  table), VIP salon behind partitions (VIP BJ + VIP roulette,
  min 500, own scaled cage, sofas) gated by NEON CIRCLE rank,
  bar counter (drinks/coffee), 10 slots (first wall unit playable,
  simple 3-reel), NEON CIRCLE loyalty counter. ~31 NPCs (dealers,
  cashiers, guards on a rectangle patrol, pit patrol, guests);
  everyone stands (no sit clip in the model set — plan-sanctioned
  fallback). Interior light: 8 warm omnis, no shadows.
- Models: 14 Blender GLBs (wheel with the real European order,
  tables with printed layouts, cage, chandelier, gate, slot, bar,
  pit-boss desk, shoe set, stool, sofa, chip) + 7 PIL-printed
  textures, all shipped as ModelBlob .tres (largest: wheel 705 KB).
  The wheel blob briefly carried a pre-fix GLB whose solid rim cap
  hid the pockets; root-caused by GLB byte comparison and fixed by
  regenerating the blob from the corrected GLB.
- Games (casino/, pure-logic classes + casino_ui.gd on CpUi):
  blackjack 6-deck S17, BJ 3:2, US peek, insurance, double, split
  to 4 hands (split aces one card, 21 not BJ); European roulette
  with the real wheel order, every bet type (straight/split/
  street/corner/six-line/dozen/column/even-money) placed on a
  clickable layout grid, wheel spin animation whose ball rest
  angle is calibrated against the model (probe shots: idx 0 rests
  in green 0, idx 1 in red 32); Texas hold'em 6-max vs 5 CPUs,
  7-card evaluation with full kicker compare, side pots via
  compute_pots, min-raise tracking, 3 CPU personalities.
  Economy: chips are separate from €$ (1:1 at the cage, presets
  100-10000 + all-in cash-out), table minimums 25 / VIP 500,
  poker buy-in 2500 (SB 25 / BB 50), no debt. NEON CIRCLE points
  = lifetime wagered / 100; GOLD (>=10000 pt) opens the VIP salon.
- Verified: casino_logic_test 113 PASS / 0 FAIL (payouts, hand
  evaluation, side pots, chip conservation over 200 simulated
  hands); casino_test integration 24 checks PASS (cage buy/sell,
  BJ settle chip math, roulette spin consistency, poker
  buy-in/leave, VIP gate) — one timing flake in the BJ reveal
  wait observed once under parallel load, then 2 clean runs;
  casino_probe PASS; blob-route run (casino .glb/.jpg removed)
  PASS, so the public build loads everything from .tres;
  existing suites v54 / v45 / v57 PASS (v54 shop-count assertion
  updated 6 -> 7 for the casino site). Xvfb photo PDCA: facade,
  overview, entrance, cage, pit, roulette, poker room, VIP,
  slots + cage/BJ/roulette/poker UI panels (13 shots in shots/).
  Draw calls at the interior overview viewpoint: 3,776 (llvmpipe).
  Staging Web export: 0 errors, pck contains all 28 casino
  model_data entries + the 4 casino scripts.
- NOT verified: iPhone fps inside the casino (8 omnis + ~31 NPCs
  + moon shadows outside), touch play of the three game panels,
  his verdict. Not pushed (awaits his "Pushして").
