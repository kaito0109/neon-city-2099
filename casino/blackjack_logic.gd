class_name BlackjackLogic
extends RefCounted
## ブラックジャックの純粋ロジック（計画書 §4.2）。
## カード表現: int 0..51（rank = c % 13 で 0=A,1=2,...,9=10,10=J,11=Q,12=K／suit = c / 13）。
## ディーラーは S17（ソフト17を含む全17でスタンド）、BJ配当 3:2、米国式ピーク、
## インシュランス（upcard A、元ベットの半分まで、配当2:1）、サレンダーなし。
##
## 実装メモ: inner class からは outer class の static を呼べない（class_name 未登録時に
## コンパイルできない）ため、点数計算の実体は兄弟 inner class HandEval に置き、
## 外側の static hand_value と Session の双方がそれを使う。

class HandEval:
	## 点数計算の実体。total は21以下の最大値（無理なら最小値）。
	static func value(cards: Array) -> Dictionary:
		var total: int = 0
		var aces: int = 0
		for c in cards:
			var r: int = int(c) % 13
			if r == 0:
				aces += 1
				total += 1
			elif r >= 9:
				total += 10
			else:
				total += r + 1
		var soft: bool = false
		if aces > 0 and total + 10 <= 21:
			total += 10
			soft = true
		return {
			"total": total,
			"soft": soft,
			"is_blackjack": cards.size() == 2 and total == 21,
			"is_bust": total > 21,
		}

	## スプリット可否判定用のポイント（A=11、10/J/Q/K=10）。
	static func point_of(card: int) -> int:
		var r: int = card % 13
		if r == 0:
			return 11
		return 10 if r >= 9 else r + 1

	## カード1枚の素点（A は 11 として数える。ピーク判定用）。
	static func is_ten_value(card: int) -> bool:
		return card % 13 >= 9


static func hand_value(cards: Array) -> Dictionary:
	return HandEval.value(cards)


class Shoe:
	extends RefCounted
	## 6デッキ312枚のシュー。残り25%（78枚）未満で要シャッフル。
	var cards: Array = []
	var rng: RandomNumberGenerator
	var _pos: int = 0

	func _init(p_rng: RandomNumberGenerator = null, p_cards: Array = []) -> void:
		rng = p_rng
		if p_cards.size() > 0:
			cards = p_cards.duplicate()
		else:
			for _d in 6:
				for c in 52:
					cards.append(c)
			shuffle()

	func shuffle() -> void:
		_pos = 0
		if cards.size() != 312:
			cards.clear()
			for _d in 6:
				for c in 52:
					cards.append(c)
		if rng != null:
			for i in range(cards.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var t: int = cards[i]
				cards[i] = cards[j]
				cards[j] = t

	## テスト用: 配られる順にカード配列を与えて積み札を作る。
	static func stacked(p_cards: Array, p_rng: RandomNumberGenerator = null) -> Shoe:
		return Shoe.new(p_rng, p_cards)

	func draw() -> int:
		if _pos >= cards.size():
			return -1
		var c: int = cards[_pos]
		_pos += 1
		return c

	func remaining() -> int:
		return cards.size() - _pos

	func needs_shuffle() -> bool:
		return remaining() < 78


class Session:
	extends RefCounted
	## 1回の着席プレイ。phase: "insurance" | "player" | "dealer" | "done"
	var player_hands: Array = [] # 各 {cards, bet, done, doubled, from_split_aces, split}
	var dealer_cards: Array = []
	var active_hand: int = 0
	var phase: String = ""
	var insurance_bet: int = 0
	var insurance_returned: int = 0
	var shoe: Shoe
	var _dealer_blackjack: bool = false
	var _settled: bool = false
	var _results: Array = []

	func start(bet: int, p_shoe: Shoe) -> void:
		shoe = p_shoe
		player_hands.clear()
		dealer_cards.clear()
		active_hand = 0
		insurance_bet = 0
		insurance_returned = 0
		_dealer_blackjack = false
		_settled = false
		_results.clear()
		var hand: Dictionary = {
			"cards": [] as Array,
			"bet": bet,
			"done": false,
			"doubled": false,
			"from_split_aces": false,
			"split": false,
		}
		player_hands.append(hand)
		# 配牌順: プレイヤー, ディーラー(up), プレイヤー, ディーラー(hole)
		hand["cards"].append(shoe.draw())
		dealer_cards.append(shoe.draw())
		hand["cards"].append(shoe.draw())
		dealer_cards.append(shoe.draw())
		_dealer_blackjack = HandEval.value(dealer_cards)["is_blackjack"]
		if _upcard() % 13 == 0:
			phase = "insurance"
		else:
			_resolve_after_peek()

	func _upcard() -> int:
		return int(dealer_cards[0]) if dealer_cards.size() > 0 else -1

	func insurance_offered() -> bool:
		return phase == "insurance"

	func take_insurance(amount: int) -> void:
		if phase != "insurance":
			return
		var cap: int = int(player_hands[0]["bet"]) / 2
		insurance_bet = clampi(amount, 0, cap)
		_resolve_after_peek()

	func decline_insurance() -> void:
		if phase != "insurance":
			return
		insurance_bet = 0
		_resolve_after_peek()

	## インシュランス判断の後（または不要な場合）にピーク結果を反映する。
	func _resolve_after_peek() -> void:
		if _dealer_blackjack:
			_finish_without_dealer_play()
			return
		if HandEval.value(player_hands[0]["cards"])["is_blackjack"]:
			_finish_without_dealer_play()
			return
		phase = "player"
		active_hand = 0

	func _active() -> Dictionary:
		return player_hands[active_hand]

	func can_hit() -> bool:
		if phase != "player":
			return false
		var h: Dictionary = _active()
		if h["done"] or h["from_split_aces"]:
			return false
		return int(HandEval.value(h["cards"])["total"]) < 21

	func can_stand() -> bool:
		if phase != "player":
			return false
		return not bool(_active()["done"])

	func can_double() -> bool:
		if phase != "player":
			return false
		var h: Dictionary = _active()
		return not h["done"] and not h["from_split_aces"] and (h["cards"] as Array).size() == 2

	func can_split() -> bool:
		if phase != "player":
			return false
		var h: Dictionary = _active()
		var cs: Array = h["cards"]
		if h["done"] or cs.size() != 2 or player_hands.size() >= 4:
			return false
		return HandEval.point_of(int(cs[0])) == HandEval.point_of(int(cs[1]))

	func hit() -> void:
		if not can_hit():
			return
		var h: Dictionary = _active()
		h["cards"].append(shoe.draw())
		if int(HandEval.value(h["cards"])["total"]) >= 21:
			h["done"] = true
			_advance()

	func stand() -> void:
		if not can_stand():
			return
		_active()["done"] = true
		_advance()

	func double_down() -> void:
		if not can_double():
			return
		var h: Dictionary = _active()
		h["bet"] = int(h["bet"]) * 2
		h["doubled"] = true
		h["cards"].append(shoe.draw())
		h["done"] = true
		_advance()

	func split_pair() -> void:
		if not can_split():
			return
		var h: Dictionary = _active()
		var cs: Array = h["cards"]
		var second: int = int(cs[1])
		cs.remove_at(1)
		var is_aces: bool = int(cs[0]) % 13 == 0
		h["split"] = true
		var nh: Dictionary = {
			"cards": [second] as Array,
			"bet": int(h["bet"]),
			"done": false,
			"doubled": false,
			"from_split_aces": is_aces,
			"split": true,
		}
		player_hands.insert(active_hand + 1, nh)
		# 現在の手→新しい手の順に1枚ずつ配る。
		cs.append(shoe.draw())
		nh["cards"].append(shoe.draw())
		if is_aces:
			# スプリットAは各1枚のみで自動スタンド。21でもBJ扱いしない。
			h["from_split_aces"] = true
			h["done"] = true
			nh["done"] = true
			_advance()
		elif int(HandEval.value(cs)["total"]) >= 21:
			h["done"] = true
			_advance()

	func _advance() -> void:
		for i in range(active_hand + 1, player_hands.size()):
			if not bool(player_hands[i]["done"]):
				active_hand = i
				return
		_finish_with_dealer_play()

	func _finish_with_dealer_play() -> void:
		phase = "dealer"
		# 全ハンドがバーストならディーラーは引かない。
		var any_live: bool = false
		for h in player_hands:
			if not bool(HandEval.value(h["cards"])["is_bust"]):
				any_live = true
		if any_live:
			dealer_play()
		_settle()

	func _finish_without_dealer_play() -> void:
		_settle()

	## S17: ソフト17を含む全17でスタンド。
	func dealer_play() -> void:
		while int(HandEval.value(dealer_cards)["total"]) < 17:
			dealer_cards.append(shoe.draw())

	func _settle() -> void:
		phase = "done"
		_settled = true
		insurance_returned = insurance_bet * 3 if _dealer_blackjack and insurance_bet > 0 else 0
		_results.clear()
		var dv: Dictionary = HandEval.value(dealer_cards)
		var dtotal: int = int(dv["total"])
		var dbust: bool = bool(dv["is_bust"])
		for h in player_hands:
			var hv: Dictionary = HandEval.value(h["cards"])
			var total: int = int(hv["total"])
			var bet: int = int(h["bet"])
			# スプリット後の2枚21はBJ扱いしない。
			var is_bj: bool = bool(hv["is_blackjack"]) and not bool(h["split"])
			var outcome: String
			var returned: int
			if bool(hv["is_bust"]):
				outcome = "bust"
				returned = 0
			elif _dealer_blackjack:
				if is_bj:
					outcome = "push"
					returned = bet
				else:
					outcome = "lose"
					returned = 0
			elif is_bj:
				outcome = "blackjack"
				returned = bet + int(round(float(bet) * 1.5))
			elif dbust:
				outcome = "dealer_bust"
				returned = bet * 2
			elif total > dtotal:
				outcome = "win"
				returned = bet * 2
			elif total < dtotal:
				outcome = "lose"
				returned = 0
			else:
				outcome = "push"
				returned = bet
			_results.append({
				"cards": (h["cards"] as Array).duplicate(),
				"total": total,
				"bet": bet,
				"outcome": outcome,
				"returned": returned,
			})

	func results() -> Array:
		return _results

	## ハンドの戻し＋インシュランスの戻しの合計。
	func total_returned() -> int:
		var sum: int = insurance_returned
		for r in _results:
			sum += int(r["returned"])
		return sum
