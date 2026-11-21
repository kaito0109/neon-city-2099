class_name RouletteLogic
extends RefCounted
## ヨーロピアン・ルーレット（シングルゼロ）の純粋ロジック。
## ベットは Dictionary {numbers:Array[int], payout:int, amount:int, label:String}。
## payout は「利益倍率」（35 なら利益が掛け金の35倍、当たれば amount*(payout+1) が戻る）。

const WHEEL_ORDER: Array[int] = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const REDS: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]


static func color_of(n: int) -> int:
	## 0=緑, 1=赤, 2=黒
	if n == 0:
		return 0
	return 1 if REDS.has(n) else 2


static func spin(rng: RandomNumberGenerator) -> int:
	## ポケットの数字そのものを返す。
	return WHEEL_ORDER[rng.randi_range(0, WHEEL_ORDER.size() - 1)]


static func _bet(numbers: Array[int], payout: int, label: String, amount: int = 0) -> Dictionary:
	return {"numbers": numbers, "payout": payout, "amount": amount, "label": label}


static func _range_bet(from_n: int, to_n: int, payout: int, label: String, amount: int = 0) -> Dictionary:
	var nums: Array[int] = []
	for n in range(from_n, to_n + 1):
		nums.append(n)
	return _bet(nums, payout, label, amount)


static func straight(n: int, amount: int = 0) -> Dictionary:
	var nums: Array[int] = [n]
	return _bet(nums, 35, "straight %d" % n, amount)


static func split(a: int, b: int, amount: int = 0) -> Dictionary:
	var nums: Array[int] = [mini(a, b), maxi(a, b)]
	return _bet(nums, 17, "split %d/%d" % [nums[0], nums[1]], amount)


static func street(first: int, amount: int = 0) -> Dictionary:
	## first in {1,4,...,34} -> [first, first+1, first+2]
	var nums: Array[int] = [first, first + 1, first + 2]
	return _bet(nums, 11, "street %d" % first, amount)


static func corner(a: int, amount: int = 0) -> Dictionary:
	## a%3==1 or 2, a<=32 -> [a, a+1, a+3, a+4]
	var nums: Array[int] = [a, a + 1, a + 3, a + 4]
	return _bet(nums, 8, "corner %d" % a, amount)


static func sixline(first: int, amount: int = 0) -> Dictionary:
	## first%3==1 -> first..first+5
	var nums: Array[int] = []
	for n in range(first, first + 6):
		nums.append(n)
	return _bet(nums, 5, "sixline %d" % first, amount)


static func dozen(i: int, amount: int = 0) -> Dictionary:
	## i=0,1,2 -> 1-12, 13-24, 25-36
	return _range_bet(i * 12 + 1, i * 12 + 12, 2, "dozen %d" % (i + 1), amount)


static func column(i: int, amount: int = 0) -> Dictionary:
	## i=0 -> n%3==0 (3,6,...,36), i=1 -> n%3==2, i=2 -> n%3==1
	var rem: int = [0, 2, 1][i]
	var nums: Array[int] = []
	for n in range(1, 37):
		if n % 3 == rem:
			nums.append(n)
	return _bet(nums, 2, "column %d" % (i + 1), amount)


static func red(amount: int = 0) -> Dictionary:
	return _bet(REDS.duplicate(), 1, "red", amount)


static func black(amount: int = 0) -> Dictionary:
	var nums: Array[int] = []
	for n in range(1, 37):
		if not REDS.has(n):
			nums.append(n)
	return _bet(nums, 1, "black", amount)


static func even(amount: int = 0) -> Dictionary:
	var nums: Array[int] = []
	for n in range(2, 37, 2):
		nums.append(n)
	return _bet(nums, 1, "even", amount)


static func odd(amount: int = 0) -> Dictionary:
	var nums: Array[int] = []
	for n in range(1, 37, 2):
		nums.append(n)
	return _bet(nums, 1, "odd", amount)


static func low(amount: int = 0) -> Dictionary:
	return _range_bet(1, 18, 1, "low 1-18", amount)


static func high(amount: int = 0) -> Dictionary:
	return _range_bet(19, 36, 1, "high 19-36", amount)


static func settle(bets: Array, pocket: int) -> Dictionary:
	## {total_bet, total_return, profit, hits} を返す。
	## 当たりは amount*(payout+1) を戻す（掛け金返却込み）。
	var total_bet: int = 0
	var total_return: int = 0
	var hits: Array = []
	for b in bets:
		var amount: int = int(b.get("amount", 0))
		total_bet += amount
		var nums: Array = b.get("numbers", [])
		if nums.has(pocket):
			var ret: int = amount * (int(b.get("payout", 0)) + 1)
			total_return += ret
			var hit: Dictionary = (b as Dictionary).duplicate()
			hit["returned"] = ret
			hits.append(hit)
	return {
		"total_bet": total_bet,
		"total_return": total_return,
		"profit": total_return - total_bet,
		"hits": hits,
	}
