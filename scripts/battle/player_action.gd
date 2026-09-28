class_name PlayerAction
extends RefCounted
## 프로토타입 전용 고정 플레이어 행동 템플릿 (타격/수비).
## 보드의 프로토타입 스펙: 타격은 STR 100% 피해(쿨 1턴), 수비는 DEX 100% 방어(쿨 2턴).
## M5에서 패턴 생성기가 플레이어에게도 적용되면 이 파일은 대체될 수 있다.

const ATTACK_ID := "attack"
const DEFENSE_ID := "defense"

const ATTACK_COOLDOWN := 1
const DEFENSE_COOLDOWN := 2


## action_id에 맞는 문장을 만든다. 모르는 id면 null.
static func build(action_id: String) -> Sentence:
	var eojeols: Array[Eojeol] = []
	match action_id:
		ATTACK_ID:
			eojeols = [
				Eojeol.new(Eojeol.Role.ADVERB, "주먹으로"),
				Eojeol.new(Eojeol.Role.VERB, "때렸다.", {
					"stat_type": StatType.Value.STR,
					"coefficient": 1.0,
					"is_defense": false,
				}),
			]
		DEFENSE_ID:
			eojeols = [
				Eojeol.new(Eojeol.Role.ADVERB, "방패로"),
				Eojeol.new(Eojeol.Role.VERB, "막았다.", {
					"stat_type": StatType.Value.DEX,
					"coefficient": 1.0,
					"is_defense": true,
				}),
			]
		_:
			return null
	return Sentence.new(eojeols)


static func cooldown_for(action_id: String) -> int:
	match action_id:
		ATTACK_ID:
			return ATTACK_COOLDOWN
		DEFENSE_ID:
			return DEFENSE_COOLDOWN
		_:
			return 0
