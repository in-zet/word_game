class_name DamageCalc
extends RefCounted
## 순수 계산 함수 모음. Combatant 상태를 직접 바꾸지 않고 값만 반환한다.

## 서술어 어절 하나의 원본 피해/효과량 (스탯 * 계수, 반올림).
static func raw_amount(actor: Combatant, verb_data: Dictionary) -> int:
	var stat: int = actor.stat_value(verb_data.get("stat_type", -1))
	var coeff: float = verb_data.get("coefficient", 1.0)
	return int(round(stat * coeff))

## 공격 원본량에서 방어량만큼 차감한다 (0 밑으로 안 내려감).
static func apply_defense(attack_amount: int, defense_amount: int) -> int:
	return max(0, attack_amount - defense_amount)

## 직접 피해량으로 강인도 감소량을 계산한다.
## 결정: 최대체력의 50%를 피해로 주면 강인도가 전부(maxPoise) 깎인다 => deal/maxHp * maxPoise * 2
static func poise_loss(deal: int, max_hp: int, max_poise: int) -> int:
	if max_hp <= 0:
		return 0
	return int(round(float(deal) / float(max_hp) * float(max_poise) * 2.0))
