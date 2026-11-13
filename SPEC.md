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
