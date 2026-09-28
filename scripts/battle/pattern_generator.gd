class_name PatternGenerator
extends RefCounted
## PatternDataResource로부터 적 문장을 만든다.
## 프로토타입 범위: 관형어, 복잡한 연결어미 변환(와/과 등) 없이
## 기본 문장 + 확률적인 단순 이어진 문장만 지원한다 (스펙 §7, M5에서 확장).

const VERB_TEXT := {
	"hit": {"base": "찌른다.", "connective": "찌르고,"},
}
const ADVERB_TEXT := {
	"dagger": "단검으로",
	"fast": "빠르게",
}
const CONNECTIVE_ADVERB_TEXT := "또"


static func verb_display_text(verb_id: String, connective: bool) -> String:
	var entry: Dictionary = VERB_TEXT.get(verb_id, {"base": verb_id + ".", "connective": verb_id + ","})
	return entry["connective"] if connective else entry["base"]


static func adverb_display_text(adverb_id: String) -> String:
	return ADVERB_TEXT.get(adverb_id, adverb_id)


## 기본 문장을 만든다. manner_adverb_id가 빈 문자열이면 방식 부사어 없이 만든다.
static func generate_base(subject_name: String, verb: VerbDataResource,
		means_adverb_id: String, manner_adverb_id: String) -> Sentence:
	var eojeols: Array[Eojeol] = []
	eojeols.append(Eojeol.new(Eojeol.Role.SUBJECT, Josa.i_ga(subject_name)))
	eojeols.append(Eojeol.new(Eojeol.Role.ADVERB, adverb_display_text(means_adverb_id)))
	if not manner_adverb_id.is_empty():
		eojeols.append(Eojeol.new(Eojeol.Role.ADVERB, adverb_display_text(manner_adverb_id)))
	eojeols.append(Eojeol.new(Eojeol.Role.VERB, verb_display_text(verb.verbID, false), {
		"stat_type": verb.statBonusType,
		"coefficient": verb.statBonusValue,
		"is_defense": false,
	}))
	return Sentence.new(eojeols)


## 이어진 문장을 만든다 (연결 부사어 + 서술어만 — 관형어/추가 부사어는 M5에서 확장).
static func generate_continuation(verb: VerbDataResource) -> Sentence:
	var eojeols: Array[Eojeol] = []
	eojeols.append(Eojeol.new(Eojeol.Role.ADVERB, CONNECTIVE_ADVERB_TEXT))
	eojeols.append(Eojeol.new(Eojeol.Role.VERB, verb_display_text(verb.verbID, false), {
		"stat_type": verb.statBonusType,
		"coefficient": verb.statBonusValue,
		"is_defense": false,
	}))
	return Sentence.new(eojeols)


## ids[i]에 weights[i] 가중치를 매겨 하나를 뽑는다. 총 가중치가 0이거나 목록이 비면 빈 문자열.
static func pick_weighted(ids: Array, weights: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0 or ids.is_empty():
		return ""
	var roll := rng.randi_range(1, total)
	var acc := 0
	for i in ids.size():
		acc += int(weights[i])
		if roll <= acc:
			return String(ids[i])
	return String(ids[ids.size() - 1])


## 방식 부사어를 adverbAppearRate 확률로 뽑는다. 실패하거나 후보가 없으면 빈 문자열.
static func roll_manner_adverb(pattern: PatternDataResource, rng: RandomNumberGenerator) -> String:
	if rng.randf() > pattern.adverbAppearRate:
		return ""
	return pick_weighted(pattern.appearableAdverbID, pattern.appearableAdverbWeight, rng)


## 이어진 문장 발생 여부를 verbAppearRate 확률로 판정한다.
static func roll_continuation(pattern: PatternDataResource, rng: RandomNumberGenerator) -> bool:
	return rng.randf() <= pattern.verbAppearRate
