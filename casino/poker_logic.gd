class_name PokerLogic
extends RefCounted
## テキサスホールデム（6人・ノーリミット）の純粋ロジック（計画書 §4.3）。
## カード表現: int 0..51（rank = c % 13 で 0=A,1=2,...,12=K／suit = c / 13）。
## スコアは辞書式比較可能な int 配列 [category, tiebreak...]（長さ6に0詰め）。
## category: 8=ストレートフラッシュ, 7=フォーカード, 6=フルハウス, 5=フラッシュ,
##           4=ストレート, 3=スリーカード, 2=ツーペア, 1=ワンペア, 0=ハイカード。
##
## 実装メモ: inner class からは outer class の static を呼べないため、評価器の実体は
## 兄弟 inner class Eval、ポット計算の実体は Pots に置き、外側 static と Game が使う。

class Eval:
	static func card_value(c: int) -> int:
		var r: int = c % 13
		return 14 if r == 0 else r + 1

	static func evaluate(cards: Array) -> Array:
		if cards.size() <= 5:
			return evaluate5(cards)
		var best: Array = []
		for combo in _combos(cards.size(), 5):
			var five: Array = []
			for i in combo:
				five.append(cards[int(i)])
			var s: Array = evaluate5(five)
			if best.is_empty() or compare(s, best) > 0:
				best = s
		return best

	static func compare(a: Array, b: Array) -> int:
		for i in mini(a.size(), b.size()):
			var d: int = int(a[i]) - int(b[i])
			if d != 0:
				return d
		return 0

	static func name_of(score: Array) -> String:
		var cat: int = int(score[0])
		if cat == 8 and score.size() > 1 and int(score[1]) == 14:
			return "ロイヤルストレートフラッシュ"
		var names: Array[String] = ["ハイカード", "ワンペア", "ツーペア", "スリーカード",
			"ストレート", "フラッシュ", "フルハウス", "フォーカード", "ストレートフラッシュ"]
		return names[clampi(cat, 0, 8)]

	static func _combos(n: int, k: int) -> Array:
		var result: Array = []
		var idx: Array = []
		for i in k:
			idx.append(i)
		while true:
			result.append(idx.duplicate())
			var i: int = k - 1
			while i >= 0 and int(idx[i]) == n - k + i:
				i -= 1
			if i < 0:
				break
			idx[i] = int(idx[i]) + 1
			for j in range(i + 1, k):
				idx[j] = int(idx[j - 1]) + 1
		return result

	static func evaluate5(cards: Array) -> Array:
		var values: Array[int] = []
		var suits: Array[int] = []
		for c in cards:
			values.append(card_value(int(c)))
			suits.append(int(c) / 13)
		values.sort()
		values.reverse()
		var flush: bool = true
		for i in range(1, suits.size()):
			if suits[i] != suits[0]:
				flush = false
		# ストレート判定（重複なし5値のときだけ成立）
		var uniq: Array[int] = []
		for v in values:
			if not uniq.has(v):
				uniq.append(v)
		var straight_high: int = 0
		if uniq.size() == 5:
			if uniq[0] - uniq[4] == 4:
				straight_high = uniq[0]
			elif uniq[0] == 14 and uniq[1] == 5 and uniq[4] == 2:
				straight_high = 5 # ホイール (A,2,3,4,5)
		# グループ化: [count, value] を count 降順 → value 降順
		var counts: Dictionary = {}
		for v in values:
			counts[v] = int(counts.get(v, 0)) + 1
		var groups: Array = []
		for v in counts.keys():
			groups.append([int(counts[v]), int(v)])
		groups.sort_custom(func(a: Array, b: Array) -> bool:
			if int(a[0]) != int(b[0]):
				return int(a[0]) > int(b[0])
			return int(a[1]) > int(b[1]))
		var cat: int
		var tb: Array[int] = []
		if straight_high > 0 and flush:
			cat = 8
			tb = [straight_high]
		elif int(groups[0][0]) == 4:
			cat = 7
			tb = [int(groups[0][1]), int(groups[1][1])]
		elif int(groups[0][0]) == 3 and int(groups[1][0]) == 2:
			cat = 6
			tb = [int(groups[0][1]), int(groups[1][1])]
		elif flush:
			cat = 5
			tb.assign(values)
		elif straight_high > 0:
			cat = 4
			tb = [straight_high]
		elif int(groups[0][0]) == 3:
			cat = 3
			tb = [int(groups[0][1])]
			var ks: Array[int] = []
			for g in groups:
				if int(g[0]) == 1:
					ks.append(int(g[1]))
			ks.sort()
			ks.reverse()
			tb.append_array(ks)
		elif int(groups[0][0]) == 2 and int(groups[1][0]) == 2:
			cat = 2
			tb = [int(groups[0][1]), int(groups[1][1]), int(groups[2][1])]
		elif int(groups[0][0]) == 2:
			cat = 1
			tb = [int(groups[0][1])]
			var ks2: Array[int] = []
			for g in groups:
				if int(g[0]) == 1:
					ks2.append(int(g[1]))
			ks2.sort()
			ks2.reverse()
			tb.append_array(ks2)
		else:
			cat = 0
			tb.assign(values)
		var score: Array = [cat]
		score.append_array(tb)
		while score.size() < 6:
			score.append(0)
		return score


class Pots:
	## players: [{committed:int, folded:bool}] -> [{amount:int, eligible:Array[int]}]
	static func compute(players: Array) -> Array:
		var levels: Array[int] = []
		for p in players:
			var c: int = int(p.get("committed", 0))
			if c > 0 and not levels.has(c):
				levels.append(c)
		levels.sort()
		var pots: Array = []
		var prev: int = 0
		for lv in levels:
			var amount: int = 0
			var eligible: Array[int] = []
			for i in players.size():
				var c: int = int(players[i].get("committed", 0))
				amount += mini(c, lv) - mini(c, prev)
				if c >= lv and not bool(players[i].get("folded", false)):
					eligible.append(i)
			if amount > 0:
				if eligible.is_empty() and not pots.is_empty():
					# 貢献者全員がフォールドした層は直前のポットへ合算する。
					pots[pots.size() - 1]["amount"] = int(pots[pots.size() - 1]["amount"]) + amount
				elif not eligible.is_empty():
					pots.append({"amount": amount, "eligible": eligible})
			prev = lv
		return pots


static func evaluate(cards: Array) -> Array:
	return Eval.evaluate(cards)


static func compare(a: Array, b: Array) -> int:
	return Eval.compare(a, b)


static func hand_name(score: Array) -> String:
	return Eval.name_of(score)


static func compute_pots(players: Array) -> Array:
	return Pots.compute(players)


class Game:
	extends RefCounted
	## 6人テキサスホールデムの1ハンド状態機械。
	## プレイヤー Dictionary: {name, stack, is_cpu, personality, cards, folded,
	##   allin, committed_hand, committed_street, acted}
	const SB: int = 25
	const BB: int = 50

	var players: Array = []
	var button: int = 0
	var rng: RandomNumberGenerator
	var board: Array = []
	var street: String = ""
	var _deck: Array = []
	var _deck_pos: int = 0
	var _current_bet: int = 0
	var _last_raise: int = BB
	var _actor: int = -1
	var _hand_over: bool = false
	var _payouts: Dictionary = {}
	var _descriptions: Dictionary = {}

	func setup(p_players: Array, p_button: int, p_rng: RandomNumberGenerator) -> void:
		players = p_players
		button = p_button
		rng = p_rng

	func start_hand() -> void:
		_hand_over = false
		_payouts = {}
		_descriptions = {}
		board = []
		street = "preflop"
		_deck = []
		for c in 52:
			_deck.append(c)
		if rng != null:
			for i in range(_deck.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var t: int = _deck[i]
				_deck[i] = _deck[j]
				_deck[j] = t
		_deck_pos = 0
		var n: int = players.size()
		for p in players:
			p["cards"] = [] as Array
			p["folded"] = int(p["stack"]) <= 0
			p["allin"] = false
			p["committed_hand"] = 0
			p["committed_street"] = 0
			p["acted"] = false
		# 配牌: ボタンの左から1枚ずつ2周
		for _round in 2:
			for k in range(1, n + 1):
				var p: Dictionary = players[(button + k) % n]
				if not bool(p["folded"]):
					(p["cards"] as Array).append(_draw_card())
		# ブラインド
		var sb_seat: int = _next_with_stack(button)
		var bb_seat: int = _next_with_stack(sb_seat)
		_post_blind(sb_seat, SB)
		_post_blind(bb_seat, BB)
		_current_bet = 0
		for p in players:
			_current_bet = maxi(_current_bet, int(p["committed_street"]))
		_last_raise = BB
		_actor = _find_actor(bb_seat)

	func _next_with_stack(from_seat: int) -> int:
		var n: int = players.size()
		for k in range(1, n + 1):
			var s: int = (from_seat + k) % n
			if int(players[s]["stack"]) > 0:
				return s
		return from_seat

	func _post_blind(seat: int, blind: int) -> void:
		var p: Dictionary = players[seat]
		var amt: int = mini(blind, int(p["stack"]))
		_pay(p, amt)

	func _pay(p: Dictionary, amt: int) -> void:
		p["stack"] = int(p["stack"]) - amt
		p["committed_street"] = int(p["committed_street"]) + amt
		p["committed_hand"] = int(p["committed_hand"]) + amt
		if int(p["stack"]) == 0:
			p["allin"] = true

	func _draw_card() -> int:
		var c: int = _deck[_deck_pos]
		_deck_pos += 1
		return c

	func is_hand_over() -> bool:
		return _hand_over

	func pot_total() -> int:
		var s: int = 0
		for p in players:
			s += int(p["committed_hand"])
		return s

	func current_actor() -> int:
		if _hand_over:
			return -1
		return _actor

	func _find_actor(from_seat: int) -> int:
		var n: int = players.size()
		for k in range(1, n + 1):
			var s: int = (from_seat + k) % n
			var p: Dictionary = players[s]
			if bool(p["folded"]) or bool(p["allin"]):
				continue
			if not bool(p["acted"]) or int(p["committed_street"]) < _current_bet:
				return s
		return -1

	func _round_complete() -> bool:
		for p in players:
			if bool(p["folded"]) or bool(p["allin"]):
				continue
			if not bool(p["acted"]) or int(p["committed_street"]) != _current_bet:
				return false
		return true

	func legal_actions() -> Dictionary:
		var res: Dictionary = {"can_check": false, "call_amount": 0, "min_raise_to": 0, "max_raise_to": 0}
		var seat: int = current_actor()
		if seat < 0:
			return res
		var p: Dictionary = players[seat]
		var to_call: int = _current_bet - int(p["committed_street"])
		res["can_check"] = to_call == 0
		res["call_amount"] = mini(maxi(to_call, 0), int(p["stack"]))
		res["min_raise_to"] = BB if _current_bet == 0 else _current_bet + _last_raise
		res["max_raise_to"] = int(p["committed_street"]) + int(p["stack"])
		return res

	## action in {"fold","check","call","bet","raise","allin"}。
	## bet/raise の amount は「このストリートの committed_street の到達先 total」。
	## 不正アクションは false を返す。
	func apply_action(seat: int, action: String, amount: int = 0) -> bool:
		if _hand_over or seat != current_actor():
			return false
		var p: Dictionary = players[seat]
		var cs: int = int(p["committed_street"])
		var stack: int = int(p["stack"])
		match action:
			"fold":
				p["folded"] = true
				p["acted"] = true
			"check":
				if _current_bet > cs:
					return false
				p["acted"] = true
			"call":
				var to_call: int = _current_bet - cs
				if to_call <= 0:
					return false
				_pay(p, mini(to_call, stack))
				p["acted"] = true
			"bet":
				if _current_bet != 0:
					return false
				if not _apply_raise_to(p, seat, amount, true):
					return false
			"raise":
				if _current_bet == 0 or amount <= _current_bet:
					return false
				if not _apply_raise_to(p, seat, amount, false):
					return false
			"allin":
				if stack <= 0:
					return false
				var target: int = cs + stack
				if target <= _current_bet:
					_pay(p, stack)
					p["acted"] = true
				elif not _apply_raise_to(p, seat, target, _current_bet == 0):
					return false
			_:
				return false
		_after_action(seat)
		return true

	## ベット/レイズの共通処理。target は committed_street の到達先。
	## ミニマムレイズ未満はオールインの場合のみ許可する簡易ルール。
	func _apply_raise_to(p: Dictionary, seat: int, target: int, is_bet: bool) -> bool:
		var cs: int = int(p["committed_street"])
		var max_to: int = cs + int(p["stack"])
		if target <= cs or target > max_to:
			return false
		var min_to: int = BB if is_bet else _current_bet + _last_raise
		var full: bool = target >= min_to
		if not full and target != max_to:
			return false
		_pay(p, target - cs)
		if full:
			_last_raise = target - _current_bet if not is_bet else target
		_current_bet = target
		# 他全員の再アクションを要求する（簡易ルール）。
		for q in players:
			if q != p and not bool(q["folded"]) and not bool(q["allin"]):
				q["acted"] = false
		p["acted"] = true
		return true

	func _after_action(seat: int) -> void:
		var alive: Array[int] = []
		for i in players.size():
			if not bool(players[i]["folded"]):
				alive.append(i)
		if alive.size() == 1:
			_finish_by_fold(alive[0])
			return
		if _round_complete():
			_advance_street()
			return
		_actor = _find_actor(seat)

	func _advance_street() -> void:
		if street == "river":
			_finish_showdown()
			return
		for p in players:
			p["committed_street"] = 0
			p["acted"] = false
		_current_bet = 0
		_last_raise = BB
		_deal_next_street()
		# アクション可能なのが1人以下なら残りを全部開いてショーダウン。
		var can_act: int = 0
		for p in players:
			if not bool(p["folded"]) and not bool(p["allin"]):
				can_act += 1
		if can_act <= 1:
			while board.size() < 5:
				_deal_next_street()
			_finish_showdown()
			return
		_actor = _find_actor(button)

	func _deal_next_street() -> void:
		match street:
			"preflop":
				street = "flop"
				for _i in 3:
					board.append(_draw_card())
			"flop":
				street = "turn"
				board.append(_draw_card())
			"turn":
				street = "river"
				board.append(_draw_card())

	func _finish_by_fold(winner: int) -> void:
		_hand_over = true
		street = "showdown"
		var pot: int = pot_total()
		players[winner]["stack"] = int(players[winner]["stack"]) + pot
		_payouts = {winner: pot}
		_descriptions = {winner: "フォールド勝ち"}

	func _finish_showdown() -> void:
		_hand_over = true
		street = "showdown"
		var lite: Array = []
		for p in players:
			lite.append({"committed": int(p["committed_hand"]), "folded": bool(p["folded"])})
		var pots: Array = Pots.compute(lite)
		_payouts = {}
		_descriptions = {}
		var n: int = players.size()
		for i in players.size():
			var p: Dictionary = players[i]
			if not bool(p["folded"]):
				var seven: Array = (p["cards"] as Array) + board
				_descriptions[i] = Eval.name_of(Eval.evaluate(seven))
		for pot in pots:
			var eligible: Array = pot["eligible"]
			var best: Array = []
			var winners: Array[int] = []
			for s in eligible:
				var seven2: Array = (players[int(s)]["cards"] as Array) + board
				var sc: Array = Eval.evaluate(seven2)
				if best.is_empty() or Eval.compare(sc, best) > 0:
					best = sc
					winners = [int(s)]
				elif Eval.compare(sc, best) == 0:
					winners.append(int(s))
			if winners.is_empty():
				continue
			# 端数はボタンに近い席（ボタンの左隣から時計回り）優先で1枚ずつ配る。
			winners.sort_custom(func(a: int, b: int) -> bool:
				return (a - button - 1 + n) % n < (b - button - 1 + n) % n)
			var amount: int = int(pot["amount"])
			var share: int = amount / winners.size()
			var rem: int = amount % winners.size()
			for wi in winners.size():
				var s2: int = winners[wi]
				var pay: int = share + (1 if wi < rem else 0)
				players[s2]["stack"] = int(players[s2]["stack"]) + pay
				_payouts[s2] = int(_payouts.get(s2, 0)) + pay

	func showdown() -> Dictionary:
		if not _hand_over:
			var alive: int = 0
			var last_alive: int = -1
			for i in players.size():
				if not bool(players[i]["folded"]):
					alive += 1
					last_alive = i
			if alive == 1:
				_finish_by_fold(last_alive)
			else:
				_finish_showdown()
		return {"payouts": _payouts.duplicate(), "descriptions": _descriptions.duplicate()}


## CPU AI: 性格 0=ルーズパッシブ, 1=タイトアグレッシブ, 2=バランス。
## 合法アクションしか返さない（legal_actions でクランプ）。
static func ai_decide(game: Game, seat: int) -> Dictionary:
	var legal: Dictionary = game.legal_actions()
	var fallback: Dictionary = {"action": "check" if bool(legal["can_check"]) else "fold", "amount": 0}
	if game.current_actor() != seat:
		return fallback
	var p: Dictionary = game.players[seat]
	var pers: int = int(p.get("personality", 2))
	var hole: Array = p["cards"]
	var eq: float
	if game.street == "preflop" or game.board.is_empty():
		eq = _preflop_equity(hole)
	else:
		eq = _postflop_equity(hole, game.board)
	var call_margin: float = [0.10, -0.03, 0.03][pers]
	var raise_thresh: float = [0.85, 0.62, 0.70][pers]
	var bluff_freq: float = [0.02, 0.08, 0.04][pers]
	var pot_frac: float = [0.5, 0.75, 0.6][pers]
	var to_call: int = int(legal["call_amount"]) # スタックでキャップ済み
	var need_call: int = game._current_bet - int(p["committed_street"])
	var pot: int = game.pot_total()
	var min_to: int = int(legal["min_raise_to"])
	var max_to: int = int(legal["max_raise_to"])
	var can_raise: bool = max_to > game._current_bet and max_to >= mini(min_to, max_to) and max_to > int(p["committed_street"])
	var rng: RandomNumberGenerator = game.rng
	var roll: float = rng.randf() if rng != null else 0.5
	# レイズ（ベット含む）: 強い手 or ブラフ
	if can_raise and max_to >= min_to and (eq >= raise_thresh or roll < bluff_freq):
		var target: int
		if game._current_bet == 0:
			target = maxi(Game.BB, int(float(maxi(pot, Game.BB)) * pot_frac))
		else:
			target = game._current_bet + maxi(Game.BB, int(float(pot) * pot_frac))
		target = clampi(target, min_to, max_to)
		return {"action": "raise" if game._current_bet > 0 else "bet", "amount": target}
	if need_call <= 0:
		return {"action": "check", "amount": 0}
	var pot_odds: float = float(need_call) / float(maxi(1, pot + need_call))
	if eq + call_margin >= pot_odds:
		return {"action": "call", "amount": 0}
	# オールインコールは少し厳しく見る
	if to_call >= int(p["stack"]) and eq < pot_odds + 0.08:
		return {"action": "fold", "amount": 0}
	return {"action": "fold", "amount": 0}


static func _preflop_equity(hole: Array) -> float:
	if hole.size() < 2:
		return 0.1
	var v1: int = Eval.card_value(int(hole[0]))
	var v2: int = Eval.card_value(int(hole[1]))
	var hi: int = maxi(v1, v2)
	var lo: int = mini(v1, v2)
	var suited: bool = int(hole[0]) / 13 == int(hole[1]) / 13
	var eq: float
	if v1 == v2:
		eq = 0.52 + float(v1 - 2) / 12.0 * 0.43
	else:
		eq = float(hi) / 14.0 * 0.42 + float(lo) / 14.0 * 0.18
		if suited:
			eq += 0.05
		if hi - lo == 1 and lo >= 5:
			eq += 0.03
		if hi == 14:
			eq += 0.04
	return clampf(eq, 0.03, 0.97)


static func _postflop_equity(hole: Array, board: Array) -> float:
	var all: Array = hole + board
	var score: Array = Eval.evaluate(all)
	var cat: int = int(score[0])
	var base_by_cat: Array[float] = [0.16, 0.36, 0.58, 0.66, 0.76, 0.80, 0.88, 0.95, 0.99]
	var eq: float = base_by_cat[cat]
	if cat == 0:
		eq += float(int(score[1])) / 14.0 * 0.10
	elif cat == 1:
		eq += float(int(score[1]) - 2) / 12.0 * 0.12
	# ドロー検出（フロップ/ターン）
	if board.size() == 3 or board.size() == 4:
		var outs: int = 0
		var suit_counts: Dictionary = {}
		var vals: Dictionary = {}
		for c in all:
			var s: int = int(c) / 13
			suit_counts[s] = int(suit_counts.get(s, 0)) + 1
			vals[Eval.card_value(int(c))] = true
		for s in suit_counts.keys():
			if int(suit_counts[s]) == 4:
				outs += 9 # フラッシュドロー
		# ストレートドロー: 5幅ウィンドウ内に異なる値が4つ
		var has_draw: bool = false
		for lo_v in range(1, 11):
			var cnt: int = 0
			for w in range(lo_v, lo_v + 5):
				var v: int = 14 if w == 1 else w # A を 1 としても数える（ホイール）
				if w == 1:
					if vals.has(14):
						cnt += 1
				elif vals.has(w):
					cnt += 1
			if cnt == 4:
				has_draw = true
		if has_draw:
			outs += 8 # オープンエンド概算（ガットショットも同枠の簡易扱い）
		var draw_eq: float = float(outs) * (0.04 if board.size() == 3 else 0.02)
		eq = maxf(eq, draw_eq)
	return clampf(eq, 0.02, 0.99)


## CPU 6人のみで hands ハンド回し、チップ保存とスタック非負を検証する。
static func simulate(rng: RandomNumberGenerator, hands: int) -> Dictionary:
	var players: Array = []
	for i in 6:
		players.append({
			"name": "CPU%d" % i, "stack": 2500, "is_cpu": true, "personality": i % 3,
			"cards": [] as Array, "folded": false, "allin": false,
			"committed_hand": 0, "committed_street": 0, "acted": false,
		})
	var initial_total: int = 2500 * 6
	var rebuy_total: int = 0
	var errors: Array[String] = []
	var button: int = 0
	for h in hands:
		var game: Game = Game.new()
		game.setup(players, button, rng)
		game.start_hand()
		var guard: int = 0
		while not game.is_hand_over():
			var actor: int = game.current_actor()
			if actor < 0:
				errors.append("hand %d: no actor but hand not over" % h)
				break
			var dec: Dictionary = ai_decide(game, actor)
			if not game.apply_action(actor, String(dec["action"]), int(dec.get("amount", 0))):
				errors.append("hand %d: AI returned illegal action %s" % [h, str(dec)])
				if not game.apply_action(actor, "fold"):
					errors.append("hand %d: fallback fold failed" % h)
					break
			guard += 1
			if guard > 2000:
				errors.append("hand %d: action loop exceeded" % h)
				break
		var sum: int = 0
		for p in players:
			if int(p["stack"]) < 0:
				errors.append("hand %d: negative stack %d" % [h, int(p["stack"])])
			sum += int(p["stack"])
		if sum != initial_total + rebuy_total:
			errors.append("hand %d: chip mismatch sum=%d expected=%d" % [h, sum, initial_total + rebuy_total])
		# リバイ: 500未満は2500まで補充し、補充総額を保存式に含める。
		for p in players:
			if int(p["stack"]) < 500:
				rebuy_total += 2500 - int(p["stack"])
				p["stack"] = 2500
		button = (button + 1) % 6
	var final_sum: int = 0
	for p in players:
		final_sum += int(p["stack"])
	return {"hands_played": hands, "errors": errors, "total_chips_accounted": final_sum}
