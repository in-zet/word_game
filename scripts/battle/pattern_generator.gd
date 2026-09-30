class_name PatternGenerator
extends RefCounted
## PatternDataResource로부터 적 문장을 만든다.
## 프로토타입 범위: 관형어, 복잡한 연결어미 변환(와/과 등) 없이
## 기본 문장 + 확률적인 단순 이어진 문장만 지원한다 (스펙 §7, M5에서 확장).

const VERB_TEXT := {
	"hit": {"base": "찌른다.", "connective": "찌르고,"},
	"slash": {"base": "벤다.", "connective": "베고,"},
	"swing": {"base": "휘두른다.", "connective": "휘두르고,"},
	"chop": {"base": "찍는다.", "connective": "찍고,"},
}
const ADVERB_TEXT := {
	"dagger": "단검으로",
	"fast": "빠르게",
	"strong": "강하게",
	"slow": "천천히",
	"sly": "몰래",
	"fierce": "사납게",
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


## weights[i]에 비례한 확률로 index i를 하나 뽑는다. weights가 비었거나 총 가중치가 0이면 0.
## ids/weights처럼 길이가 안 맞을 수 있는 두 배열을 다룰 때는 min(len)까지만 본다(방어적).
static func pick_weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	if weights.is_empty():
		return 0
	var total := 0
	for w in weights:
		total += max(0, int(w))
	if total <= 0:
		return 0
	var roll := rng.randi_range(1, total)
	var acc := 0
	for i in weights.size():
		acc += max(0, int(weights[i]))
		if roll <= acc:
			return i
	return weights.size() - 1


## ids[i]에 weights[i] 가중치를 매겨 하나를 뽑는다. 총 가중치가 0이거나 목록이 비면 빈 문자열
## (pick_weighted_index와 달리 "뽑을 게 없다"를 빈 문자열로 명확히 구분해야 해서 총합을 직접 본다).
static func pick_weighted(ids: Array, weights: Array, rng: RandomNumberGenerator) -> String:
	var n: int = min(ids.size(), weights.size())
	if n <= 0:
		return ""
	var trimmed_weights: Array = weights.slice(0, n)
	var total := 0
	for w in trimmed_weights:
		total += max(0, int(w))
	if total <= 0:
		return ""
	return String(ids[pick_weighted_index(trimmed_weights, rng)])


## 방식 부사어를 adverbAppearRate 확률로 뽑는다. 실패하거나 후보가 없으면 빈 문자열.
static func roll_manner_adverb(pattern: PatternDataResource, rng: RandomNumberGenerator) -> String:
	if rng.randf() > pattern.adverbAppearRate:
		return ""
	return pick_weighted(pattern.appearableAdverbID, pattern.appearableAdverbWeight, rng)


## 이어진 문장 발생 여부를 verbAppearRate 확률로 판정한다.
static func roll_continuation(pattern: PatternDataResource, rng: RandomNumberGenerator) -> bool:
	return rng.randf() <= pattern.verbAppearRate
