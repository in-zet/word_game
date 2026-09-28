@tool
extends EditorScript

const Combatant = preload("res://scripts/battle/combatant.gd")
const DamageCalc = preload("res://scripts/battle/damage_calc.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("Combatant/DamageCalc")

	var goblin := Combatant.new("고블린", 100, 8, 6, 100)
	t.check("초기 hp", goblin.hp, 100)
	t.check("초기 is_alive", goblin.is_alive(), true)
	goblin.take_damage(150)
	t.check("hp는 0 밑으로 안 내려감", goblin.hp, 0)
	t.check("hp 0이면 사망", goblin.is_alive(), false)

	var p := Combatant.new("플레이어", 100, 12, 10, 100)
	t.check("STR 조회", p.stat_value(StatType.Value.STR), 12)
	t.check("DEX 조회", p.stat_value(StatType.Value.DEX), 10)
	t.check("NONE 조회는 0", p.stat_value(StatType.Value.NONE), 0)

	t.check("쿨타임 없으면 사용 가능", p.is_action_ready("attack"), true)
	p.start_cooldown("attack", 2)
	t.check("쿨타임 걸리면 사용 불가", p.is_action_ready("attack"), false)
	p.tick_cooldowns()
	t.check("한 턴 지나면 쿨타임 감소", p.is_action_ready("attack"), false)
	p.tick_cooldowns()
	t.check("쿨타임 다 지나면 사용 가능", p.is_action_ready("attack"), true)

	p.reduce_poise(50)
	t.check("강인도 감소", p.poise, 50)
	t.check("강인도 0 아니면 그로기 아님", p.is_broken(), false)
	p.reduce_poise(1000)
	t.check("강인도도 0 밑으로 안 내려감", p.poise, 0)
	t.check("강인도 0이면 그로기", p.is_broken(), true)

	var raw := DamageCalc.raw_amount(p, {"stat_type": StatType.Value.STR, "coefficient": 1.0})
	t.check("raw_amount = STR * 계수", raw, 12)
	t.check("apply_defense: 방어가 더 작음", DamageCalc.apply_defense(12, 5), 7)
	t.check("apply_defense: 방어가 더 큼 -> 0", DamageCalc.apply_defense(5, 12), 0)

	t.check("poise_loss: 최대체력 50% 피해면 강인도 전부", DamageCalc.poise_loss(50, 100, 100), 100)
	t.check("poise_loss: 최대체력 25% 피해면 강인도 절반", DamageCalc.poise_loss(25, 100, 100), 50)
	t.check("poise_loss: maxHp 0이면 0", DamageCalc.poise_loss(10, 0, 100), 0)

	t.report()
