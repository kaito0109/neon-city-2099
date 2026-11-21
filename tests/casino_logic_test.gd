extends SceneTree
## カジノ3ゲームの純粋ロジック単体テスト（計画書 §9）。
## 実行: Godot --headless --path . --script tests/casino_logic_test.gd
## class_name 登録に依存しないよう preload で読む。

const RL = preload("res://casino/roulette_logic.gd")
const BJ = preload("res://casino/blackjack_logic.gd")
const PK = preload("res://casino/poker_logic.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, " ", detail)


func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


## カード生成: rank 0=A,1=2,...,8=9,9=10,10=J,11=Q,12=K / suit 0..3
func _c(rank: int, suit: int = 0) -> int:
	return suit * 13 + rank


func _initialize() -> void:
	_test_roulette()
	_test_blackjack()
	_test_poker()
	print("TOTAL pass=%d fail=%d" % [_pass, _fail])
	if _fail > 0:
		quit(1)
	else:
		print("CASINO_LOGIC_ALL_PASS")
		quit(0)


# ---------------------------------------------------------------- roulette

func _test_roulette() -> void:
	# ホイール配列: 37ポケット・0..36 がちょうど1回ずつ
	var seen: Dictionary = {}
	for n in RL.WHEEL_ORDER:
		seen[n] = true
	_ok(RL.WHEEL_ORDER.size() == 37 and seen.size() == 37, "roulette_wheel_order",
		"size=%d uniq=%d" % [RL.WHEEL_ORDER.size(), seen.size()])
	# REDS と color_of の整合
	var red_count: int = 0
	var black_count: int = 0
	var consistent: bool = true
	for n in range(0, 37):
		var col: int = RL.color_of(n)
		if n == 0:
			consistent = consistent and col == 0
		elif RL.REDS.has(n):
			consistent = consistent and col == 1
			red_count += 1
		else:
			consistent = consistent and col == 2
			black_count += 1
	_ok(consistent and red_count == 18 and black_count == 18 and RL.REDS.size() == 18,
		"roulette_colors", "red=%d black=%d" % [red_count, black_count])
	# 全ベット種の numbers サイズと重複なし
	var cases: Array = [
		["straight", RL.straight(7), 1], ["split", RL.split(7, 8), 2],
		["street", RL.street(7), 3], ["corner", RL.corner(7), 4],
		["sixline", RL.sixline(7), 6], ["dozen", RL.dozen(1), 12],
		["column", RL.column(0), 12], ["red", RL.red(), 18],
		["black", RL.black(), 18], ["even", RL.even(), 18],
		["odd", RL.odd(), 18], ["low", RL.low(), 18], ["high", RL.high(), 18],
	]
	for cs in cases:
		var nums: Array = cs[1]["numbers"]
		var uniq: Dictionary = {}
		for n in nums:
			uniq[n] = true
		_ok(nums.size() == int(cs[2]) and uniq.size() == nums.size(),
			"roulette_bet_size_%s" % cs[0], "size=%d uniq=%d" % [nums.size(), uniq.size()])
	# コラム定義: col0 は 3,6,...,36
	var col0: Array = RL.column(0)["numbers"]
	_ok(col0.size() == 12 and int(col0[0]) == 3 and int(col0[11]) == 36, "roulette_column_def", str(col0))
	# settle: straight 0 に 100 → 3600 戻し
	var r1: Dictionary = RL.settle([RL.straight(0, 100)], 0)
	_ok(int(r1["total_return"]) == 3600 and int(r1["total_bet"]) == 100 and int(r1["profit"]) == 3500,
		"roulette_settle_straight_zero", str(r1))
	# red 100, pocket=1(赤) → 200 / pocket=0 → 0
	var r2: Dictionary = RL.settle([RL.red(100)], 1)
	_ok(int(r2["total_return"]) == 200, "roulette_settle_red_hit", str(r2))
	var r3: Dictionary = RL.settle([RL.red(100)], 0)
	_ok(int(r3["total_return"]) == 0 and (r3["hits"] as Array).is_empty(), "roulette_settle_red_zero", str(r3))
	# dozen(0) pocket=12 → 3倍戻し
	var r4: Dictionary = RL.settle([RL.dozen(0, 100)], 12)
	_ok(int(r4["total_return"]) == 300, "roulette_settle_dozen", str(r4))
	# 複合ベット: straight7(50)+red(100)+dozen(1)(25), pocket=7 → 1800+200
	var r5: Dictionary = RL.settle([RL.straight(7, 50), RL.red(100), RL.dozen(1, 25)], 7)
	_ok(int(r5["total_bet"]) == 175 and int(r5["total_return"]) == 2000 and (r5["hits"] as Array).size() == 2,
		"roulette_settle_mixed", str(r5))
	# spin: シード固定で決定的・範囲内
	var s1: int = RL.spin(_rng(1234))
	var s2: int = RL.spin(_rng(1234))
	_ok(s1 == s2 and RL.WHEEL_ORDER.has(s1), "roulette_spin_deterministic", "%d vs %d" % [s1, s2])


# ---------------------------------------------------------------- blackjack

func _hv(cards: Array) -> Dictionary:
	return BJ.hand_value(cards)


func _test_blackjack() -> void:
	# hand_value 表
	var v1: Dictionary = _hv([_c(0), _c(5)])
	_ok(int(v1["total"]) == 17 and bool(v1["soft"]), "bj_hv_A6_soft17", str(v1))
	var v2: Dictionary = _hv([_c(0), _c(5), _c(8)])
	_ok(int(v2["total"]) == 16 and not bool(v2["soft"]), "bj_hv_A69_hard16", str(v2))
	var v3: Dictionary = _hv([_c(0), _c(0, 1), _c(8)])
	_ok(int(v3["total"]) == 21 and not bool(v3["is_blackjack"]), "bj_hv_AA9_21", str(v3))
	var v4: Dictionary = _hv([_c(9), _c(12)])
	_ok(int(v4["total"]) == 20, "bj_hv_10K_20", str(v4))
	var v5: Dictionary = _hv([_c(0), _c(12)])
	_ok(int(v5["total"]) == 21 and bool(v5["is_blackjack"]), "bj_hv_AK_blackjack", str(v5))
	var v6: Dictionary = _hv([_c(9), _c(8), _c(4)])
	_ok(int(v6["total"]) == 24 and bool(v6["is_bust"]), "bj_hv_bust", str(v6))
	# Shoe: 312枚、カットカード閾値
	var shoe = BJ.Shoe.new(_rng(7))
	_ok(shoe.remaining() == 312 and not shoe.needs_shuffle(), "bj_shoe_312", "rem=%d" % shoe.remaining())
	for _i in 234:
		shoe.draw()
	_ok(shoe.remaining() == 78 and not shoe.needs_shuffle(), "bj_shoe_cut_78", "rem=%d" % shoe.remaining())
	shoe.draw()
	_ok(shoe.remaining() == 77 and shoe.needs_shuffle(), "bj_shoe_cut_77", "rem=%d" % shoe.remaining())
	# プレイヤーBJ 3:2: bet100 → returned 250（配牌 P,D,P,D）
	var s_bj = BJ.Session.new()
	s_bj.start(100, BJ.Shoe.stacked([_c(0), _c(8), _c(12), _c(6)], _rng(1)))
	var rb: Array = s_bj.results()
	_ok(s_bj.phase == "done" and rb.size() == 1 and rb[0]["outcome"] == "blackjack" and int(rb[0]["returned"]) == 250,
		"bj_player_blackjack_3to2", "phase=%s res=%s" % [s_bj.phase, str(rb)])
	# ディーラー ソフト17 スタンド（A+6）。5枚目=4: ヒットすると21になり負ける配牌で検証。
	var s_s17 = BJ.Session.new()
	s_s17.start(100, BJ.Shoe.stacked([_c(9), _c(0, 1), _c(7), _c(5), _c(3)], _rng(1)))
	_ok(s_s17.phase == "insurance" and s_s17.insurance_offered(), "bj_insurance_phase_on_ace", s_s17.phase)
	s_s17.decline_insurance()
	s_s17.stand() # プレイヤー 10+8=18
	var rs17: Array = s_s17.results()
	_ok(s_s17.dealer_cards.size() == 2 and rs17.size() == 1 and rs17[0]["outcome"] == "win" and int(rs17[0]["returned"]) == 200,
		"bj_dealer_soft17_stands", "dealer=%s res=%s" % [str(s_s17.dealer_cards), str(rs17)])
	# バースト負け
	var s_bust = BJ.Session.new()
	s_bust.start(100, BJ.Shoe.stacked([_c(9), _c(8), _c(8, 1), _c(6), _c(4)], _rng(1)))
	s_bust.hit() # 10+9+5=24
	var rbu: Array = s_bust.results()
	_ok(rbu.size() == 1 and rbu[0]["outcome"] == "bust" and int(rbu[0]["returned"]) == 0 and s_bust.dealer_cards.size() == 2,
		"bj_bust_loses", str(rbu))
	# プッシュ（両者19）
	var s_push = BJ.Session.new()
	s_push.start(100, BJ.Shoe.stacked([_c(9), _c(9, 1), _c(8), _c(8, 1)], _rng(1)))
	s_push.stand()
	var rp: Array = s_push.results()
	_ok(rp.size() == 1 and rp[0]["outcome"] == "push" and int(rp[0]["returned"]) == 100, "bj_push", str(rp))
	# ダブル成功: 11 + 10 = 21 vs ディーラー17、bet倍化で 400 戻し
	var s_dbl = BJ.Session.new()
	s_dbl.start(100, BJ.Shoe.stacked([_c(4), _c(9, 1), _c(5), _c(6), _c(9)], _rng(1)))
	_ok(s_dbl.can_double(), "bj_can_double", s_dbl.phase)
	s_dbl.double_down()
	var rd: Array = s_dbl.results()
	_ok(rd.size() == 1 and int(rd[0]["bet"]) == 200 and rd[0]["outcome"] == "win" and int(rd[0]["returned"]) == 400,
		"bj_double_win", str(rd))
	# ダブル失敗: 11 + 2 = 13 vs 17
	var s_dbl2 = BJ.Session.new()
	s_dbl2.start(100, BJ.Shoe.stacked([_c(4), _c(9, 1), _c(5), _c(6), _c(1)], _rng(1)))
	s_dbl2.double_down()
	var rd2: Array = s_dbl2.results()
	_ok(rd2.size() == 1 and rd2[0]["outcome"] == "lose" and int(rd2[0]["returned"]) == 0, "bj_double_lose", str(rd2))
	# スプリット可否: 10 と K は10点同士で可
	var s_tk = BJ.Session.new()
	s_tk.start(100, BJ.Shoe.stacked([_c(9), _c(8), _c(12), _c(6)], _rng(1)))
	_ok(s_tk.can_split(), "bj_can_split_ten_king", s_tk.phase)
	# スプリット 8,8 → 2ハンド、ディーラー16→バーストで両方 dealer_bust
	var s_sp = BJ.Session.new()
	s_sp.start(100, BJ.Shoe.stacked([_c(7), _c(9), _c(7, 1), _c(5), _c(9, 1), _c(9, 2), _c(9, 3)], _rng(1)))
	_ok(s_sp.can_split(), "bj_can_split_88", s_sp.phase)
	s_sp.split_pair()
	_ok(s_sp.player_hands.size() == 2, "bj_split_makes_2_hands", "hands=%d" % s_sp.player_hands.size())
	s_sp.stand() # 手1: 8+10=18
	s_sp.stand() # 手2: 8+10=18 → ディーラー 16+10=26 バースト
	var rsp: Array = s_sp.results()
	_ok(rsp.size() == 2 and rsp[0]["outcome"] == "dealer_bust" and rsp[1]["outcome"] == "dealer_bust"
		and s_sp.total_returned() == 400, "bj_split_88_settle", str(rsp))
	# スプリットA: 各1枚のみ・21は通常勝ち（3:2にならない）
	var s_sa = BJ.Session.new()
	s_sa.start(100, BJ.Shoe.stacked([_c(0), _c(9), _c(0, 1), _c(6), _c(12), _c(8)], _rng(1)))
	s_sa.split_pair() # 手1: A+K=21、手2: A+9=20、両方自動スタンド、ディーラー17
	var rsa: Array = s_sa.results()
	_ok(s_sa.phase == "done" and rsa.size() == 2 and rsa[0]["outcome"] == "win" and int(rsa[0]["returned"]) == 200
		and rsa[1]["outcome"] == "win" and int(rsa[1]["returned"]) == 200,
		"bj_split_aces_one_card_no_bj", "phase=%s res=%s" % [s_sa.phase, str(rsa)])
	# インシュランス: ディーラーBJ時 insurance 50 → 戻し150、本ベットは負け
	var s_ins = BJ.Session.new()
	s_ins.start(100, BJ.Shoe.stacked([_c(9), _c(0), _c(8), _c(12)], _rng(1)))
	_ok(s_ins.insurance_offered(), "bj_insurance_offered", s_ins.phase)
	s_ins.take_insurance(50)
	var ri: Array = s_ins.results()
	_ok(s_ins.phase == "done" and ri.size() == 1 and ri[0]["outcome"] == "lose" and int(ri[0]["returned"]) == 0
		and s_ins.insurance_returned == 150 and s_ins.total_returned() == 150,
		"bj_insurance_pays_on_dealer_bj", "ins_ret=%d total=%d res=%s" % [s_ins.insurance_returned, s_ins.total_returned(), str(ri)])
	# インシュランス: ディーラーBJでない時は没収（本ベット20は勝ち）
	var s_ins2 = BJ.Session.new()
	s_ins2.start(100, BJ.Shoe.stacked([_c(9), _c(0, 1), _c(12), _c(5)], _rng(1)))
	s_ins2.take_insurance(50) # ディーラーは A+6 ソフト17
	s_ins2.stand() # プレイヤー 10+K=20
	_ok(s_ins2.insurance_returned == 0 and s_ins2.total_returned() == 200,
		"bj_insurance_lost_when_no_dealer_bj", "ins_ret=%d total=%d" % [s_ins2.insurance_returned, s_ins2.total_returned()])


# ---------------------------------------------------------------- poker

func _pc(s: String) -> int:
	var ranks: String = "A23456789TJQK"
	var suits: String = "shdc"
	return suits.find(s.substr(1, 1)) * 13 + ranks.find(s.substr(0, 1))


func _hand(s: String) -> Array:
	var out: Array = []
	for tok in s.split(" ", false):
		out.append(_pc(tok))
	return out


func _ev(s: String) -> Array:
	return PK.evaluate(_hand(s))


func _cmp_case(name: String, a: String, b: String, expected_sign: int) -> void:
	var d: int = PK.compare(_ev(a), _ev(b))
	var got: int = sign(d)
	_ok(got == expected_sign, "poker_cmp_%s" % name, "%s vs %s diff=%d" % [a, b, d])


func _cat_case(name: String, cards: String, expected_cat: int) -> void:
	var sc: Array = _ev(cards)
	_ok(int(sc[0]) == expected_cat, "poker_cat_%s" % name, "%s score=%s" % [cards, str(sc)])


func _test_poker() -> void:
	# カテゴリ判定（5枚）
	_cat_case("royal_sf", "As Ks Qs Js Ts", 8)
	_cat_case("sf", "9h 8h 7h 6h 5h", 8)
	_cat_case("wheel_sf", "Ac 2c 3c 4c 5c", 8)
	_cat_case("four", "As Ah Ad Ac Ks", 7)
	_cat_case("fullhouse", "As Ah Ad Ks Kh", 6)
	_cat_case("flush", "As Js 8s 5s 2s", 5)
	_cat_case("straight", "9s 8d 7c 6h 5s", 4)
	_cat_case("wheel", "As 2d 3c 4h 5s", 4)
	_cat_case("trips", "As Ah Ad Kc 2s", 3)
	_cat_case("twopair", "As Ah Ks Kh 2c", 2)
	_cat_case("pair", "As Ah Ks Qc 2s", 1)
	_cat_case("high", "As Kh Qc 9s 2d", 0)
	# カテゴリ判定（7枚から最良5枚）
	_cat_case("royal_7", "As Ks Qs Js Ts 2d 3c", 8)
	_cat_case("two_trips_fh_7", "As Ah Ad Ks Kh Kd 2c", 6)
	_cat_case("flush_7", "As 2s 5s 7s 9s Js 3d", 5)
	_cat_case("wheel_7", "As 2d 3c 4h 5s Kd Qc", 4)
	_cat_case("run_7", "9s 8d 7c 6h 5s 4d 2c", 4)
	# ホイールは5ハイ
	_ok(int(_ev("As 2d 3c 4h 5s")[1]) == 5, "poker_wheel_is_5high", str(_ev("As 2d 3c 4h 5s")))
	# 勝敗比較（キッカーまで）
	_cmp_case("royal_vs_sf", "As Ks Qs Js Ts", "9h 8h 7h 6h 5h", 1)
	_cmp_case("sf6_vs_wheelsf", "6d 5d 4d 3d 2d", "Ac 2c 3c 4c 5c", 1)
	_cmp_case("fourA_vs_fourK", "As Ah Ad Ac 2s", "Ks Kh Kd Kc 3s", 1)
	_cmp_case("four_kicker", "As Ah Ad Ac Ks", "As Ah Ad Ac Qs", 1)
	_cmp_case("fh_trip_first", "As Ah Ad 2s 2h", "Ks Kh Kd As Ah", 1)
	_cmp_case("fh_pair_part", "3s 3h 3d As Ah", "3s 3h 3d 2s 2c", 1)
	_cmp_case("fh_aaa_vs_kkk", "As Ah Ad Ks Kh", "Ks Kh Kd As Ah", 1)
	_cmp_case("flush_ahigh", "As 9s 7s 5s 2s", "Ks Qs 7s 5s 2s", 1)
	_cmp_case("flush_2nd_card", "As Ks 7s 5s 2s", "As Qs Js 5s 2s", 1)
	_cmp_case("straight_9v8", "9s 8d 7c 6h 5s", "8s 7d 6c 5h 4s", 1)
	_cmp_case("wheel_vs_6straight", "As 2d 3c 4h 5s", "6s 5d 4c 3h 2s", -1)
	_cmp_case("wheel_vs_pair", "As 2d 3c 4h 5s", "As Ah Kd Qc 2s", 1)
	_cmp_case("trips_kicker", "As Ah Ad Ks 2c", "As Ah Ad Qs 2c", 1)
	_cmp_case("trips_rank", "Ks Kh Kd As 2c", "As Ah Ad 3s 2c", -1)
	_cmp_case("twopair_kicker", "As Ah Ks Kh Qc", "As Ah Ks Kh Jc", 1)
	_cmp_case("twopair_2ndpair", "As Ah Ks Kh 2c", "As Ah Qs Qh Kc", 1)
	_cmp_case("twopair_kicker2", "Ks Kh Qs Qh As", "Ks Kh Qs Qh Jc", 1)
	_cmp_case("pair_rank", "As Ah Kd Qc 2s", "Ks Kh Ad Qc 2s", 1)
	_cmp_case("pair_kicker", "Ks Kh As Qc 2d", "Ks Kh Qs Jc 2d", 1)
	_cmp_case("pair_kicker2", "Ks Kh As Qc 2d", "Ks Kh As Jc 2d", 1)
	_cmp_case("high_ak_vs_aq", "As Kd Qc 9h 2s", "As Qd Jc 9h 2s", 1)
	_cmp_case("high_exact_tie", "As Kd Qc 9h 2s", "Ah Ks Qd 9c 2h", 0)
	_cmp_case("flush_vs_straight", "As 9s 7s 5s 2s", "9c 8d 7c 6h 5s", 1)
	_cmp_case("fh_vs_flush", "As Ah Ad Ks Kh", "As 9s 7s 5s 2s", 1)
	_cmp_case("twopair_vs_pair", "As Ah Ks Kh 2c", "As Ah Kd Qc Js", 1)
	_cmp_case("sf_vs_four", "5h 4h 3h 2h Ah", "As Ah Ad Ac Ks", 1)
	_cmp_case("board_chop_royal", "As Ks Qs Js Ts 2d 3c", "As Ks Qs Js Ts 7h 8d", 0)
	_cmp_case("board_pair_kicker_7", "As Qd Ks Kh 7c 2s 3d", "As Jd Ks Kh 7c 2s 3d", 1)
	_cmp_case("run7_vs_straight8", "9s 8d 7c 6h 5s 4d 2c", "8s 7d 6c 5h 4s", 1)
	# ハンド名（日本語）
	_ok(PK.hand_name(_ev("As Js 8s 5s 2s")) == "フラッシュ", "poker_name_flush", PK.hand_name(_ev("As Js 8s 5s 2s")))
	_ok(PK.hand_name(_ev("As Ah Ad Ks Kh")) == "フルハウス", "poker_name_fullhouse", PK.hand_name(_ev("As Ah Ad Ks Kh")))
	_ok(PK.hand_name(_ev("As Ks Qs Js Ts")) == "ロイヤルストレートフラッシュ", "poker_name_royal", PK.hand_name(_ev("As Ks Qs Js Ts")))
	_ok(PK.hand_name(_ev("As Ah Ks Kh 2c")) == "ツーペア", "poker_name_twopair", PK.hand_name(_ev("As Ah Ks Kh 2c")))
	# compute_pots: 3人オールイン 100/300/1000
	var pots: Array = PK.compute_pots([
		{"committed": 100, "folded": false},
		{"committed": 300, "folded": false},
		{"committed": 1000, "folded": false},
	])
	_ok(pots.size() == 3 and int(pots[0]["amount"]) == 300 and int(pots[1]["amount"]) == 400 and int(pots[2]["amount"]) == 700,
		"poker_pots_amounts", str(pots))
	_ok((pots[0]["eligible"] as Array).size() == 3 and (pots[1]["eligible"] as Array).size() == 2
		and (pots[2]["eligible"] as Array).size() == 1 and int((pots[2]["eligible"] as Array)[0]) == 2,
		"poker_pots_eligible", str(pots))
	# フォールドした人のチップはポットに入るが eligible に入らない
	var pots_f: Array = PK.compute_pots([
		{"committed": 100, "folded": true},
		{"committed": 300, "folded": false},
		{"committed": 1000, "folded": false},
	])
	var f_total: int = 0
	var f_ok: bool = true
	for pt in pots_f:
		f_total += int(pt["amount"])
		if (pt["eligible"] as Array).has(0):
			f_ok = false
	_ok(f_total == 1400 and f_ok, "poker_pots_folded_chips", str(pots_f))
	# ミニマムレイズ: BB50 → 100以上、次は前回レイズ幅以上
	var players: Array = _mk_players()
	var g = PK.Game.new()
	g.setup(players, 0, _rng(99))
	g.start_hand()
	_ok(g.current_actor() == 3, "poker_first_actor_utg", "actor=%d" % g.current_actor())
	_ok(int(players[1]["committed_street"]) == 25 and int(players[2]["committed_street"]) == 50,
		"poker_blinds", "%d/%d" % [int(players[1]["committed_street"]), int(players[2]["committed_street"])])
	var la: Dictionary = g.legal_actions()
	_ok(int(la["min_raise_to"]) == 100, "poker_minraise_first", str(la))
	_ok(not g.apply_action(3, "raise", 90), "poker_raise_below_min_rejected")
	_ok(not g.apply_action(4, "fold"), "poker_wrong_seat_rejected")
	_ok(g.apply_action(3, "raise", 150), "poker_raise_150_ok")
	var la2: Dictionary = g.legal_actions()
	_ok(g.current_actor() == 4 and int(la2["min_raise_to"]) == 250, "poker_minraise_second",
		"actor=%d la=%s" % [g.current_actor(), str(la2)])
	_ok(not g.apply_action(4, "raise", 200), "poker_raise_200_rejected")
	_ok(g.apply_action(4, "raise", 250), "poker_raise_250_ok")
	# 全員フォールド → BB がポット獲得
	var players2: Array = _mk_players()
	var g2 = PK.Game.new()
	g2.setup(players2, 0, _rng(5))
	g2.start_hand()
	var guard: int = 0
	while not g2.is_hand_over() and guard < 50:
		var a: int = g2.current_actor()
		if a < 0:
			break
		g2.apply_action(a, "fold")
		guard += 1
	var sd: Dictionary = g2.showdown()
	_ok(g2.is_hand_over() and int(players2[2]["stack"]) == 2525 and int((sd["payouts"] as Dictionary).get(2, 0)) == 75,
		"poker_fold_win_bb", "bb_stack=%d payouts=%s" % [int(players2[2]["stack"]), str(sd["payouts"])])
	# CPUのみ200ハンド自動対戦で破綻ゼロ
	var sim: Dictionary = PK.simulate(_rng(20261121), 200)
	_ok(int(sim["hands_played"]) == 200 and (sim["errors"] as Array).is_empty(),
		"poker_simulate_200", str(sim["errors"]))
	_ok(int(sim["total_chips_accounted"]) >= 15000, "poker_simulate_chips", str(sim["total_chips_accounted"]))


func _mk_players() -> Array:
	var players: Array = []
	for i in 6:
		players.append({
			"name": "P%d" % i, "stack": 2500, "is_cpu": true, "personality": i % 3,
			"cards": [] as Array, "folded": false, "allin": false,
			"committed_hand": 0, "committed_street": 0, "acted": false,
		})
	return players
