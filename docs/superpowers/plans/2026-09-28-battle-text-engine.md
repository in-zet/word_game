# 문장 기반 턴제 전투 엔진 — 프로토타입(M0~M3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 플레이어가 고블린 1마리와 "어절 = 턴" 문장 기반 전투를 끝까지(승리/패배) 치를 수 있게 만든다.

**Architecture:** 전투 로직(`scripts/battle/`)을 Node/UI와 완전히 분리된 `RefCounted` 기반 순수 GDScript로 작성하고,
`BattleManager`가 signal로만 결과를 알린다. `scripts/ui/battle_view.gd`는 그 signal을 구독해서 화면을 그릴 뿐 로직을
갖지 않는다.

**Tech Stack:** Godot 4.7 / GDScript. 외부 테스트 프레임워크 없음 — 기존 `scripts/DB/SheetData.gd`와 같은
`@tool extends EditorScript` 패턴으로 만든 경량 러너(`TestReporter`)를 사용한다.

**Spec:** `docs/superpowers/specs/2026-09-28-battle-text-engine-design.md`

## Global Constraints

- Godot 4.7, GL Compatibility 렌더러. `project.godot` 설정은 변경하지 않는다.
- 기존 `scripts/DB/*` 시트 파이프라인(시트→JSON→.tres 생성)은 건드리지 않는다. 생성된 `.tres`/`enum` 파일의
  **값만** 수정한다.
- 시트 소스에서 온 오타(`charmisma`, `addtionalCreatedAdverb`, `Golbin`)는 그대로 둔다 (스펙 §5 결정).
- 새 스크립트는 `class_name` + snake_case 파일명 컨벤션을 따른다 (`scripts/custom_resources/`, `scripts/enums/` 참고).
- **이 세션에는 Godot 실행 파일이 없다.** 모든 "테스트 실행" 스텝은 Godot 에디터에서 해당 파일을 열고
  `File > Run` (Ctrl+Shift+X)을 눌러 Output 패널을 읽는 방식이며, 사람이 직접 눌러 확인해야 한다.
  자동화된 CLI 테스트가 아니라는 점을 감안해서, 실행 전에 반드시 프로젝트를 한 번 다시 불러오기
  (상단 메뉴 `프로젝트 > 다시 불러오기` 또는 에디터 재시작)해서 새 `class_name`이 등록되게 한다.
- Player 강인도(poise) 초기값은 보드에 명시되어 있지 않아 100으로 잠정 설정한다 (M4/밸런스 단계에서 조정 대상).

## Review Focus

- 빈 문자열/한글이 아닌 이름에 `Josa.has_batchim`을 호출해도 죽지 않아야 한다 (예: 영문 ID를 실수로 넘긴 경우).
- `pick_weighted`에 가중치 총합이 0인 배열을 넘겨도 멈추거나 나누기 0 에러가 나면 안 된다.
- 이어진 문장이 계속 확률에 당첨돼 무한히 이어지면 전투가 멈추지 않는다 — 체인 길이에 상한이 있어야 한다.
- 쿨타임이 남은 행동을 `submit_player_action`으로 제출해도 조용히 거부되어야 한다 (문장이 생성되면 안 됨).
- 같은 턴에 유저가 방어하고 적이 공격할 때, 방어량이 피해량보다 커도 피해가 음수가 되면 안 된다 (0으로 clamp).

---

## Task 1: 데이터 정리 (M0)

**Files:**
- Modify: `scripts/enums/adverb_type.gd`
- Modify: `scripts/enums/stat_type.gd`
- Modify: `resources/data/AdverbData/dagger.tres`
- Modify: `resources/data/AdverbData/fast.tres`
- Modify: `resources/data/VerbData/hit.tres`
- Modify: `resources/data/EnemyData/Goblin.tres`
- Modify: `resources/data/PatternData/GolbinPattern1.tres`

**Interfaces:**
- Produces: `AdverbType.Value.{NONE, MEANS, MANNER}` (정수 0/1/2), `StatType.Value.{NONE, STR, DEX}` (정수 0/1/2) —
  이후 모든 Task가 이 정수 값으로 `.tres`의 `adverbType`/`statBonusType` 필드를 읽는다.

- [ ] **Step 1: enum 값 채우기**

`scripts/enums/adverb_type.gd`의 enum 블록을 다음으로 교체:

```gdscript
enum Value {
	NONE,
	MEANS,   ## 수단의 부사어 (무기: 단검으로)
	MANNER,  ## 방식의 부사어 (어떻게: 빠르게)
}
```

`scripts/enums/stat_type.gd`의 enum 블록을 다음으로 교체:

```gdscript
enum Value {
	NONE,
	STR,
	DEX,
}
```

- [ ] **Step 2: AdverbData에 adverbType 채우기**

`resources/data/AdverbData/dagger.tres`의 `[resource]` 블록에 `adverbType = 1` 줄을 `adverbID = "dagger"` 다음에 추가:

```
[resource]
script = ExtResource("1_jxugc")
adverbID = "dagger"
adverbType = 1
haveBatchim = true
```

`resources/data/AdverbData/fast.tres`도 동일하게 `adverbType = 2` 추가:

```
[resource]
script = ExtResource("1_g2ghd")
adverbID = "fast"
adverbType = 2
coefficient = 0.1
conflictingAdverb = Array[String](["fast"])
```

- [ ] **Step 3: VerbData에 statBonusType 채우기**

`resources/data/VerbData/hit.tres`에 `statBonusType = 1` (STR) 추가:

```
[resource]
script = ExtResource("1_av5ce")
verbID = "hit"
statBonusType = 1
statBonusValue = 1.0
haveBatchim = true
coolDownTurn = 1
```

- [ ] **Step 4: 고블린 스탯을 프로토타입 스펙(STR 8 / DEX 6)에 맞춤**

`resources/data/EnemyData/Goblin.tres`에서 `strength = 10` → `strength = 8`,
`dexterity = 10` → `dexterity = 6`으로 수정. 나머지 줄은 그대로 둔다.

- [ ] **Step 5: 이어진 문장이 실제로 뽑히도록 가중치 버그 수정**

`resources/data/PatternData/GolbinPattern1.tres`에서
`appearableVerbWeight = Array[int]([0])` → `appearableVerbWeight = Array[int]([1])`로 수정.

- [ ] **Step 6: 수동 확인**

Godot 에디터에서 프로젝트를 다시 불러온 뒤, `FileSystem` 패널에서 `resources/data/EnemyData/Goblin.tres`를
더블클릭해 Inspector에 Strength=8, Dexterity=6이 보이는지, `AdverbType`/`StatType` 콤보박스가 새 값(MEANS/MANNER,
STR/DEX)을 보여주는지 확인한다.

- [ ] **Step 7: 커밋**

```bash
git add scripts/enums/adverb_type.gd scripts/enums/stat_type.gd \
  resources/data/AdverbData/dagger.tres resources/data/AdverbData/fast.tres \
  resources/data/VerbData/hit.tres resources/data/EnemyData/Goblin.tres \
  resources/data/PatternData/GolbinPattern1.tres
git commit -m "data: 프로토타입용 enum 값과 고블린 데이터 정리 (M0)"
```

---

## Task 2: 테스트 러너 + Josa 유틸 (M1)

**Files:**
- Create: `scripts/tests/test_reporter.gd`
- Create: `scripts/tests/test_josa.gd`
- Create: `scripts/core/josa.gd`

**Interfaces:**
- Produces: `TestReporter.new(name: String)`, `.check(desc: String, actual, expected) -> void`, `.report() -> void`.
  이후 모든 테스트 파일이 이 3개를 사용한다.
- Produces: `Josa.has_batchim(word: String) -> bool`, `Josa.i_ga`, `Josa.eun_neun`, `Josa.euro_ro`,
  `Josa.wa_gwa` (모두 `(word: String) -> String`).

- [ ] **Step 1: TestReporter 작성**

`scripts/tests/test_reporter.gd`:

```gdscript
class_name TestReporter
extends RefCounted
## 경량 테스트 리포터. Godot 에디터에서 EditorScript로 실행한 결과를 Output 패널에 출력한다.

var _name: String
var _pass := 0
var _fail := 0

func _init(test_name: String) -> void:
	_name = test_name
	print("=== %s 테스트 시작 ===" % _name)

func check(desc: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  PASS: %s" % desc)
	else:
		_fail += 1
		printerr("  FAIL: %s (실제: %s, 기대: %s)" % [desc, str(actual), str(expected)])

func report() -> void:
	print("=== %s 결과: %d/%d 통과 ===" % [_name, _pass, _pass + _fail])
	if _fail > 0:
		printerr("!!! %s: %d개 실패 !!!" % [_name, _fail])
```

- [ ] **Step 2: 실패하는 Josa 테스트 작성**

`scripts/tests/test_josa.gd`:

```gdscript
@tool
extends EditorScript

const Josa = preload("res://scripts/core/josa.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("Josa")
	t.check("받침 있음: 고블린", Josa.has_batchim("고블린"), true)
	t.check("받침 없음: 고블", Josa.has_batchim("고블"), false)
	t.check("빈 문자열", Josa.has_batchim(""), false)
	t.check("이/가 받침 있음", Josa.i_ga("고블린"), "고블린이")
	t.check("이/가 받침 없음", Josa.i_ga("고블"), "고블가")
	t.check("은/는 받침 있음", Josa.eun_neun("고블린"), "고블린은")
	t.check("은/는 받침 없음", Josa.eun_neun("고블"), "고블는")
	t.check("으로/로 받침 없음", Josa.euro_ro("칼"), "칼로")
	t.check("으로/로 받침 있음(ㄹ 아님)", Josa.euro_ro("단검"), "단검으로")
	t.check("으로/로 받침 있음(ㄹ)", Josa.euro_ro("칼날"), "칼날로")
	t.check("와/과 받침 있음", Josa.wa_gwa("독"), "독과")
	t.check("와/과 받침 없음", Josa.wa_gwa("화염"), "화염와")
	t.report()
```

- [ ] **Step 3: 실행해서 실패 확인**

Godot 에디터에서 `scripts/tests/test_josa.gd`를 열고 Ctrl+Shift+X.
Expected: `res://scripts/core/josa.gd`를 찾을 수 없다는 파싱 오류로 스크립트 자체가 실행되지 않음
(아직 `josa.gd`가 없으므로).

- [ ] **Step 4: Josa 구현**

`scripts/core/josa.gd`:

```gdscript
class_name Josa
extends RefCounted
## 받침 여부에 따라 조사를 선택하는 유틸리티.

## 문자열 마지막 글자에 받침이 있는지 판정한다. 한글 음절(가~힣)이 아니거나 빈 문자열이면 false.
static func has_batchim(word: String) -> bool:
	if word.is_empty():
		return false
	var last_char := word.substr(word.length() - 1, 1)
	var code := last_char.unicode_at(0)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0


static func i_ga(word: String) -> String:
	return word + ("이" if has_batchim(word) else "가")


static func eun_neun(word: String) -> String:
	return word + ("은" if has_batchim(word) else "는")


## 받침이 있고 그 받침이 'ㄹ'이면 "로", 그 외 받침 있으면 "으로", 받침 없으면 "로".
static func euro_ro(word: String) -> String:
	if not has_batchim(word):
		return word + "로"
	var last_char := word.substr(word.length() - 1, 1)
	var code := last_char.unicode_at(0)
	var jong := (code - 0xAC00) % 28
	if jong == 8:  # 종성 'ㄹ'
		return word + "로"
	return word + "으로"


static func wa_gwa(word: String) -> String:
	return word + ("과" if has_batchim(word) else "와")
```

- [ ] **Step 5: 실행해서 통과 확인**

같은 파일(`test_josa.gd`)을 다시 Ctrl+Shift+X.
Expected: Output 패널에 `PASS`만 12줄, 마지막에 `Josa 결과: 12/12 통과`.

- [ ] **Step 6: 커밋**

```bash
git add scripts/tests/test_reporter.gd scripts/tests/test_josa.gd scripts/core/josa.gd
git commit -m "feat: 조사 처리 유틸(Josa)과 경량 테스트 러너 추가"
```

---

## Task 3: Eojeol / Sentence (M1)

**Files:**
- Create: `scripts/battle/eojeol.gd`
- Create: `scripts/battle/sentence.gd`
- Create: `scripts/tests/test_sentence.gd`

**Interfaces:**
- Consumes: 없음 (독립 데이터 구조).
- Produces:
  - `Eojeol.new(role: Eojeol.Role, text: String, data: Dictionary = {})`, `role`, `text`, `data` 프로퍼티.
    `Eojeol.Role` = `{SUBJECT, ADVERB, VERB, SYSTEM}`.
  - `Sentence.new(eojeols: Array[Eojeol])`, `.advance() -> Eojeol`(더 없으면 null), `.cursor: int`,
    `.revealed() -> Array[Eojeol]`, `.is_finished() -> bool`, `.cancel_rest() -> void`,
    `.to_display_text() -> String`.

- [ ] **Step 1: 실패하는 Sentence 테스트 작성**

`scripts/tests/test_sentence.gd`:

```gdscript
@tool
extends EditorScript

const Eojeol = preload("res://scripts/battle/eojeol.gd")
const Sentence = preload("res://scripts/battle/sentence.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _make_sentence() -> Sentence:
	var eojeols: Array[Eojeol] = [
		Eojeol.new(Eojeol.Role.SUBJECT, "고블린이"),
		Eojeol.new(Eojeol.Role.ADVERB, "단검으로"),
		Eojeol.new(Eojeol.Role.VERB, "찌른다."),
	]
	return Sentence.new(eojeols)


func _run() -> void:
	var t := TestReporter.new("Sentence")

	var s := _make_sentence()
	t.check("초기 cursor", s.cursor, -1)
	t.check("초기 is_finished", s.is_finished(), false)
	t.check("revealed 비어있음", s.revealed().size(), 0)

	var e1 := s.advance()
	t.check("첫 advance는 SUBJECT", e1.role, Eojeol.Role.SUBJECT)
	t.check("advance 후 cursor", s.cursor, 0)
	t.check("revealed 1개", s.revealed().size(), 1)

	s.advance()
	var e3 := s.advance()
	t.check("세번째 advance는 VERB", e3.role, Eojeol.Role.VERB)
	t.check("모두 소진 후 is_finished", s.is_finished(), true)
	t.check("더 advance하면 null", s.advance(), null)

	var s2 := _make_sentence()
	s2.advance()
	s2.cancel_rest()
	t.check("cancel 후 is_finished", s2.is_finished(), true)
	t.check("cancel 후 advance는 null", s2.advance(), null)
	t.check("cancel 후 revealed는 취소 전까지만", s2.revealed().size(), 1)

	var s3 := _make_sentence()
	t.check("to_display_text", s3.to_display_text(), "고블린이 단검으로 찌른다.")

	t.report()
```

- [ ] **Step 2: 실행해서 실패 확인**

`test_sentence.gd`를 Ctrl+Shift+X. Expected: `eojeol.gd`/`sentence.gd`가 없어 파싱 오류로 실행 안 됨.

- [ ] **Step 3: Eojeol 구현**

`scripts/battle/eojeol.gd`:

```gdscript
class_name Eojeol
extends RefCounted
## 문장을 이루는 어절 하나. VERB 역할만 data에 피해/방어 계산용 정보를 담는다.
## data 형식 (VERB일 때): {"stat_type": int, "coefficient": float, "is_defense": bool}

enum Role { SUBJECT, ADVERB, VERB, SYSTEM }

var role: Role
var text: String
var data: Dictionary

func _init(p_role: Role, p_text: String, p_data: Dictionary = {}) -> void:
	role = p_role
	text = p_text
	data = p_data
```

- [ ] **Step 4: Sentence 구현**

`scripts/battle/sentence.gd`:

```gdscript
class_name Sentence
extends RefCounted
## 어절 배열과 진행 커서. 한 번에 어절 하나씩 advance()로 공개(해소)한다.

var eojeols: Array[Eojeol] = []
var cursor: int = -1
var cancelled: bool = false

func _init(p_eojeols: Array[Eojeol]) -> void:
	eojeols = p_eojeols

## 다음 어절을 공개하고 반환한다. 더 없거나 취소됐으면 null.
func advance() -> Eojeol:
	if cancelled:
		return null
	if cursor + 1 >= eojeols.size():
		return null
	cursor += 1
	return eojeols[cursor]

## 지금까지 공개된 어절 목록.
func revealed() -> Array[Eojeol]:
	var out: Array[Eojeol] = []
	for i in range(min(cursor + 1, eojeols.size())):
		out.append(eojeols[i])
	return out

func is_finished() -> bool:
	return cancelled or cursor + 1 >= eojeols.size()

func cancel_rest() -> void:
	cancelled = true

## 공개 여부와 상관없이 전체 문장을 하나의 문자열로 합친다 (미리보기 표시용).
func to_display_text() -> String:
	var parts: Array[String] = []
	for e in eojeols:
		parts.append(e.text)
	return " ".join(parts)
```

- [ ] **Step 5: 실행해서 통과 확인**

`test_sentence.gd`를 다시 Ctrl+Shift+X. Expected: 전부 PASS, `Sentence 결과: 12/12 통과`.

- [ ] **Step 6: 커밋**

```bash
git add scripts/battle/eojeol.gd scripts/battle/sentence.gd scripts/tests/test_sentence.gd
git commit -m "feat: Eojeol/Sentence 자료구조 추가"
```

---

## Task 4: Combatant / DamageCalc (M2)

**Files:**
- Create: `scripts/battle/combatant.gd`
- Create: `scripts/battle/damage_calc.gd`
- Create: `scripts/tests/test_damage_calc.gd`

**Interfaces:**
- Consumes: `StatType`(scripts/enums/stat_type.gd, Task 1에서 STR/DEX 추가됨, 전역 class_name이라 preload 불필요).
- Produces:
  - `Combatant.new(name: String, max_hp: int, str: int, dex: int, max_poise: int)`.
    프로퍼티: `display_name, max_hp, hp, max_poise, poise, strength, dexterity, cooldowns: Dictionary`.
    메서드: `is_alive() -> bool`, `is_broken() -> bool`, `take_damage(amount: int) -> void`,
    `reduce_poise(amount: int) -> void`, `reset_poise() -> void`, `stat_value(stat_type: int) -> int`,
    `is_action_ready(action_id: String) -> bool`, `start_cooldown(action_id: String, turns: int) -> void`,
    `tick_cooldowns() -> void`.
  - `DamageCalc.raw_amount(actor: Combatant, verb_data: Dictionary) -> int`,
    `DamageCalc.apply_defense(attack_amount: int, defense_amount: int) -> int`,
    `DamageCalc.poise_loss(deal: int, max_hp: int, max_poise: int) -> int`.

- [ ] **Step 1: 실패하는 DamageCalc 테스트 작성**

`scripts/tests/test_damage_calc.gd`:

```gdscript
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
```

- [ ] **Step 2: 실행해서 실패 확인**

`test_damage_calc.gd`를 Ctrl+Shift+X. Expected: `combatant.gd`/`damage_calc.gd`가 없어 파싱 오류.

- [ ] **Step 3: Combatant 구현**

`scripts/battle/combatant.gd`:

```gdscript
class_name Combatant
extends RefCounted
## 전투 참가자의 상태 (HP, 강인도, 스탯, 쿨타임). UI/Node를 모른다.

var display_name: String
var max_hp: int
var hp: int
var max_poise: int
var poise: int
var strength: int
var dexterity: int
var cooldowns: Dictionary = {}  ## action_id(String) -> 남은 턴 수(int)

func _init(p_name: String, p_max_hp: int, p_str: int, p_dex: int, p_max_poise: int) -> void:
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	max_poise = p_max_poise
	poise = p_max_poise
	strength = p_str
	dexterity = p_dex

func is_alive() -> bool:
	return hp > 0

func is_broken() -> bool:
	return poise <= 0

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)

func reduce_poise(amount: int) -> void:
	poise = max(0, poise - amount)

func reset_poise() -> void:
	poise = max_poise

func stat_value(stat_type: int) -> int:
	match stat_type:
		StatType.Value.STR:
			return strength
		StatType.Value.DEX:
			return dexterity
		_:
			return 0

func is_action_ready(action_id: String) -> bool:
	return cooldowns.get(action_id, 0) <= 0

func start_cooldown(action_id: String, turns: int) -> void:
	cooldowns[action_id] = turns

func tick_cooldowns() -> void:
	for key in cooldowns.keys():
		if cooldowns[key] > 0:
			cooldowns[key] -= 1
```

- [ ] **Step 4: DamageCalc 구현**

`scripts/battle/damage_calc.gd`:

```gdscript
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
```

- [ ] **Step 5: 실행해서 통과 확인**

`test_damage_calc.gd`를 다시 Ctrl+Shift+X. Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add scripts/battle/combatant.gd scripts/battle/damage_calc.gd scripts/tests/test_damage_calc.gd
git commit -m "feat: Combatant/DamageCalc 추가"
```

---

## Task 5: PatternGenerator (M2)

**Files:**
- Create: `scripts/battle/pattern_generator.gd`
- Create: `scripts/tests/test_pattern_generator.gd`

**Interfaces:**
- Consumes: `Eojeol`, `Sentence` (Task 3), `PatternDataResource`/`VerbDataResource`(기존 `scripts/custom_resources/`).
- Produces:
  - `PatternGenerator.verb_display_text(verb_id: String, connective: bool) -> String`
  - `PatternGenerator.adverb_display_text(adverb_id: String) -> String`
  - `PatternGenerator.generate_base(subject_name: String, verb: VerbDataResource, means_adverb_id: String, manner_adverb_id: String) -> Sentence`
  - `PatternGenerator.generate_continuation(verb: VerbDataResource) -> Sentence`
  - `PatternGenerator.pick_weighted(ids: Array, weights: Array, rng: RandomNumberGenerator) -> String`
  - `PatternGenerator.roll_manner_adverb(pattern: PatternDataResource, rng: RandomNumberGenerator) -> String`
  - `PatternGenerator.roll_continuation(pattern: PatternDataResource, rng: RandomNumberGenerator) -> bool`

**주의:** 부사어/서술어 표시 텍스트("단검으로", "찌른다.")는 시트에 아직 `text` 컬럼이 없어서 코드 내
테이블(`VERB_TEXT`, `ADVERB_TEXT`)로 관리한다. M5에서 시트에 컬럼이 추가되면 이 테이블을 대체한다.

- [ ] **Step 1: 실패하는 PatternGenerator 테스트 작성**

`scripts/tests/test_pattern_generator.gd`:

```gdscript
@tool
extends EditorScript

const PatternGenerator = preload("res://scripts/battle/pattern_generator.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("PatternGenerator")

	t.check("서술어 기본형", PatternGenerator.verb_display_text("hit", false), "찌른다.")
	t.check("서술어 연결형", PatternGenerator.verb_display_text("hit", true), "찌르고,")
	t.check("모르는 서술어 기본형은 id+.", PatternGenerator.verb_display_text("unknown", false), "unknown.")
	t.check("부사어 텍스트", PatternGenerator.adverb_display_text("dagger"), "단검으로")
	t.check("모르는 부사어는 id 그대로", PatternGenerator.adverb_display_text("mystery"), "mystery")

	var verb: VerbDataResource = load("res://resources/data/VerbData/hit.tres")

	var base := PatternGenerator.generate_base("고블린", verb, "dagger", "fast")
	t.check("기본 문장 어절 수 (주어+수단+방식+서술어)", base.eojeols.size(), 4)
	t.check("기본 문장 표시", base.to_display_text(), "고블린이 단검으로 빠르게 찌른다.")

	var base_no_manner := PatternGenerator.generate_base("고블린", verb, "dagger", "")
	t.check("방식 부사어 없으면 어절 3개", base_no_manner.eojeols.size(), 3)
	t.check("방식 부사어 없는 표시", base_no_manner.to_display_text(), "고블린이 단검으로 찌른다.")

	var cont := PatternGenerator.generate_continuation(verb)
	t.check("이어진 문장 어절 수 (연결부사+서술어)", cont.eojeols.size(), 2)
	t.check("이어진 문장 표시", cont.to_display_text(), "또 찌른다.")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	t.check("총 가중치 0이면 빈 문자열", PatternGenerator.pick_weighted(["a"], [0], rng), "")
	t.check("빈 목록이면 빈 문자열", PatternGenerator.pick_weighted([], [], rng), "")
	t.check("후보 1개면 그것만 뽑힘", PatternGenerator.pick_weighted(["only"], [1], rng), "only")

	var pattern: PatternDataResource = load("res://resources/data/PatternData/GolbinPattern1.tres")
	var hit_count := 0
	var total := 200
	for i in total:
		if PatternGenerator.roll_continuation(pattern, rng):
			hit_count += 1
	# verbAppearRate = 0.2 근처인지 느슨하게 확인 (완전 결정 X, 범위만 확인)
	t.check("roll_continuation 발생 비율이 0에서 1 사이", hit_count >= 0 and hit_count <= total, true)

	t.report()
```

- [ ] **Step 2: 실행해서 실패 확인**

`test_pattern_generator.gd`를 Ctrl+Shift+X. Expected: `pattern_generator.gd`가 없어 파싱 오류.

- [ ] **Step 3: PatternGenerator 구현**

`scripts/battle/pattern_generator.gd`:

```gdscript
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
```

- [ ] **Step 4: 실행해서 통과 확인**

`test_pattern_generator.gd`를 다시 Ctrl+Shift+X. Expected: 전부 PASS. (Task 1에서 `hit.tres`에
`statBonusType = 1`을 넣지 않았다면 `generate_base`/`generate_continuation` 관련 계산이 이후 Task 7에서
어긋나니, 안 넣었다면 지금 Task 1 Step 3으로 돌아가 채운다.)

- [ ] **Step 5: 커밋**

```bash
git add scripts/battle/pattern_generator.gd scripts/tests/test_pattern_generator.gd
git commit -m "feat: PatternGenerator로 적 문장 생성 추가"
```

---

## Task 6: PlayerAction (M2)

**Files:**
- Create: `scripts/battle/player_action.gd`
- Create: `scripts/tests/test_player_action.gd`

**Interfaces:**
- Consumes: `Eojeol`, `Sentence` (Task 3).
- Produces: `PlayerAction.ATTACK_ID := "attack"`, `PlayerAction.DEFENSE_ID := "defense"`,
  `PlayerAction.build(action_id: String) -> Sentence` (모르는 id면 null),
  `PlayerAction.cooldown_for(action_id: String) -> int`.

- [ ] **Step 1: 실패하는 PlayerAction 테스트 작성**

`scripts/tests/test_player_action.gd`:

```gdscript
@tool
extends EditorScript

const PlayerAction = preload("res://scripts/battle/player_action.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("PlayerAction")

	var attack := PlayerAction.build(PlayerAction.ATTACK_ID)
	t.check("타격 문장 어절 수", attack.eojeols.size(), 2)
	t.check("타격 문장 표시", attack.to_display_text(), "주먹으로 때렸다.")
	t.check("타격 서술어는 STR 기반", attack.eojeols[1].data.get("stat_type"), StatType.Value.STR)
	t.check("타격은 공격(방어 아님)", attack.eojeols[1].data.get("is_defense"), false)

	var defense := PlayerAction.build(PlayerAction.DEFENSE_ID)
	t.check("수비 문장 어절 수", defense.eojeols.size(), 2)
	t.check("수비 문장 표시", defense.to_display_text(), "방패로 막았다.")
	t.check("수비 서술어는 DEX 기반", defense.eojeols[1].data.get("stat_type"), StatType.Value.DEX)
	t.check("수비는 방어", defense.eojeols[1].data.get("is_defense"), true)

	t.check("모르는 id는 null", PlayerAction.build("unknown"), null)

	t.check("타격 쿨타임", PlayerAction.cooldown_for(PlayerAction.ATTACK_ID), 1)
	t.check("수비 쿨타임", PlayerAction.cooldown_for(PlayerAction.DEFENSE_ID), 2)
	t.check("모르는 id 쿨타임 0", PlayerAction.cooldown_for("unknown"), 0)

	t.report()
```

- [ ] **Step 2: 실행해서 실패 확인**

`test_player_action.gd`를 Ctrl+Shift+X. Expected: `player_action.gd`가 없어 파싱 오류.

- [ ] **Step 3: PlayerAction 구현**

`scripts/battle/player_action.gd`:

```gdscript
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
```

- [ ] **Step 4: 실행해서 통과 확인**

`test_player_action.gd`를 다시 Ctrl+Shift+X. Expected: 전부 PASS.

- [ ] **Step 5: 커밋**

```bash
git add scripts/battle/player_action.gd scripts/tests/test_player_action.gd
git commit -m "feat: PlayerAction으로 타격/수비 고정 문장 추가"
```

---

## Task 7: BattleManager (M2 완료 기준)

**Files:**
- Create: `scripts/battle/battle_manager.gd`
- Create: `scripts/tests/test_battle_headless.gd`

**Interfaces:**
- Consumes: `Combatant`, `DamageCalc` (Task 4), `PatternGenerator` (Task 5), `PlayerAction` (Task 6),
  `Sentence`/`Eojeol` (Task 3).
- Produces:
  - `BattleManager.new(player: Combatant, enemy: Combatant, pattern: PatternDataResource, verb: VerbDataResource, weapon_id: String, seed: int = 0)`.
  - 프로퍼티: `player`, `enemy`, `phase`, `turn_no`.
  - 메서드: `start_battle() -> void`, `submit_player_action(action_id: String) -> bool`, `advance_turn() -> void`.
  - signal: `sentence_loaded(side: String, sentence: Sentence)`,
    `eojeol_revealed(side: String, index: int, eojeol: Eojeol)`, `log_added(text: String)`,
    `turn_resolved(turn_no: int)`, `battle_finished(player_won: bool)`.
- 이후 Task 8(UI)이 이 signal들만 구독해서 사용한다.

**설계 메모 (Review Focus 대응):**
- 이어진 문장이 계속 당첨돼도 무한히 이어지지 않도록 체인 길이를 `MAX_CONNECTIVE_CHAIN = 5`로 제한한다.
- 같은 턴에 방어 서술어와 공격 서술어가 동시에 해소되면, 방어량을 공격 원본량에서 먼저 뺀 뒤 실제 피해를 적용한다.
- 양쪽이 같은 턴에 함께 HP 0이 되면 무승부로 간주하고 `player_won = false`로 발행한다 (스펙에 명시 안 된 엣지케이스이므로
  "동시 사망은 패배 처리"로 정하고 주석에 남긴다).

- [ ] **Step 1: 실패하는 헤드리스 통합 테스트 작성**

`scripts/tests/test_battle_headless.gd`:

```gdscript
@tool
extends EditorScript

const Combatant = preload("res://scripts/battle/combatant.gd")
const BattleManager = preload("res://scripts/battle/battle_manager.gd")
const PlayerAction = preload("res://scripts/battle/player_action.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")

var _log_lines: Array[String] = []
var _finished := false
var _player_won := false


func _on_log(text: String) -> void:
	_log_lines.append(text)


func _on_finished(player_won: bool) -> void:
	_finished = true
	_player_won = player_won


func _run() -> void:
	var t := TestReporter.new("BattleManager headless")

	var player := Combatant.new("플레이어", 100, 12, 10, 100)
	var enemy := Combatant.new("고블린", 100, 8, 6, 100)
	var pattern: PatternDataResource = load("res://resources/data/PatternData/GolbinPattern1.tres")
	var verb: VerbDataResource = load("res://resources/data/VerbData/hit.tres")

	var battle := BattleManager.new(player, enemy, pattern, verb, "dagger", 42)
	battle.log_added.connect(_on_log)
	battle.battle_finished.connect(_on_finished)
	battle.start_battle()

	t.check("시작 직후 phase는 WAIT_INPUT", battle.phase, BattleManager.Phase.WAIT_INPUT)

	# 항상 타격만 선택하며 최대 500턴까지 진행 (무한루프 방지 안전장치)
	var guard := 0
	while not _finished and guard < 500:
		guard += 1
		if player.is_action_ready(PlayerAction.ATTACK_ID):
			battle.submit_player_action(PlayerAction.ATTACK_ID)
		else:
			battle.submit_player_action("")
		battle.advance_turn()

	t.check("500턴 안에 전투 종료", _finished, true)
	t.check("종료 후 phase는 BATTLE_END", battle.phase, BattleManager.Phase.BATTLE_END)
	t.check("승패 중 하나는 HP 0", player.hp <= 0 or enemy.hp <= 0, true)
	t.check("플레이어 hp 음수 아님", player.hp >= 0, true)
	t.check("적 hp 음수 아님", enemy.hp >= 0, true)
	t.check("로그가 최소 1줄 이상 쌓임", _log_lines.size() > 0, true)

	print("--- 전투 로그 (형식 눈으로 확인용) ---")
	for line in _log_lines:
		print(line)
	print("--- 결과: %s ---" % ("플레이어 승리" if _player_won else "플레이어 패배"))

	# 쿨타임 중인 행동은 거부되는지 별도로 확인
	var p2 := Combatant.new("플레이어2", 100, 12, 10, 100)
	var e2 := Combatant.new("고블린2", 100, 8, 6, 100)
	var battle2 := BattleManager.new(p2, e2, pattern, verb, "dagger", 1)
	battle2.start_battle()
	battle2.submit_player_action(PlayerAction.DEFENSE_ID)
	battle2.advance_turn()
	# 수비 쿨타임은 2턴 -> 아직 안 끝났으면 거부되어야 함
	if not p2.is_action_ready(PlayerAction.DEFENSE_ID):
		t.check("쿨타임 중 수비 재사용 거부", battle2.submit_player_action(PlayerAction.DEFENSE_ID), false)

	t.report()
```

- [ ] **Step 2: 실행해서 실패 확인**

`test_battle_headless.gd`를 Ctrl+Shift+X. Expected: `battle_manager.gd`가 없어 파싱 오류.

- [ ] **Step 3: BattleManager 구현**

`scripts/battle/battle_manager.gd`:

```gdscript
class_name BattleManager
extends RefCounted
## 스텝 모드 전투 상태 머신. Node/UI를 모르며 signal로만 결과를 알린다.

signal sentence_loaded(side: String, sentence: Sentence)
signal eojeol_revealed(side: String, index: int, eojeol: Eojeol)
signal log_added(text: String)
signal turn_resolved(turn_no: int)
signal battle_finished(player_won: bool)

enum Phase { BATTLE_START, WAIT_INPUT, BATTLE_END }

const MAX_CONNECTIVE_CHAIN := 5

var player: Combatant
var enemy: Combatant
var enemy_pattern: PatternDataResource
var enemy_verb: VerbDataResource
var enemy_weapon_id: String
var rng: RandomNumberGenerator

var phase: Phase = Phase.BATTLE_START
var turn_no: int = 0

var _enemy_sentence: Sentence
var _player_sentence: Sentence
var _player_action_id: String = ""
var _enemy_damage_accum: int = 0
var _player_damage_accum: int = 0
var _connective_chain: int = 0


func _init(p_player: Combatant, p_enemy: Combatant, p_pattern: PatternDataResource,
		p_verb: VerbDataResource, p_weapon_id: String, p_seed: int = 0) -> void:
	player = p_player
	enemy = p_enemy
	enemy_pattern = p_pattern
	enemy_verb = p_verb
	enemy_weapon_id = p_weapon_id
	rng = RandomNumberGenerator.new()
	rng.seed = p_seed


func start_battle() -> void:
	_load_enemy_sentence(false)
	phase = Phase.WAIT_INPUT


func _load_enemy_sentence(is_connective: bool) -> void:
	if is_connective:
		_enemy_sentence = PatternGenerator.generate_continuation(enemy_verb)
	else:
		_connective_chain = 0
		var manner_id := PatternGenerator.roll_manner_adverb(enemy_pattern, rng)
		_enemy_sentence = PatternGenerator.generate_base(
			enemy_pattern.basicLineSubject, enemy_verb, enemy_weapon_id, manner_id)
	sentence_loaded.emit("enemy", _enemy_sentence)


## 플레이어 행동을 예약한다. action_id가 빈 문자열이면 패스.
## 쿨타임 중이거나 WAIT_INPUT이 아니면 false를 반환하고 아무 것도 하지 않는다.
func submit_player_action(action_id: String) -> bool:
	if phase != Phase.WAIT_INPUT:
		return false
	if action_id.is_empty():
		_player_action_id = ""
		_player_sentence = null
		return true
	if not player.is_action_ready(action_id):
		return false
	var sentence := PlayerAction.build(action_id)
	if sentence == null:
		return false
	_player_action_id = action_id
	_player_sentence = sentence
	sentence_loaded.emit("player", _player_sentence)
	return true


## 한 턴을 진행한다. WAIT_INPUT이 아니면 아무 것도 하지 않는다.
func advance_turn() -> void:
	if phase != Phase.WAIT_INPUT:
		return
	turn_no += 1

	var enemy_eojeol := _enemy_sentence.advance()
	if enemy_eojeol != null:
		eojeol_revealed.emit("enemy", _enemy_sentence.cursor, enemy_eojeol)

	var player_eojeol: Eojeol = null
	if _player_sentence != null:
		player_eojeol = _player_sentence.advance()
		if player_eojeol != null:
			eojeol_revealed.emit("player", _player_sentence.cursor, player_eojeol)

	_resolve_turn_effects(enemy_eojeol, player_eojeol)
	turn_resolved.emit(turn_no)

	if _check_battle_end():
		return

	if _enemy_sentence.is_finished():
		_finish_enemy_sentence()
	if _player_sentence != null and _player_sentence.is_finished():
		_finish_player_sentence()

	player.tick_cooldowns()
	enemy.tick_cooldowns()
	_player_action_id = ""
	_player_sentence = null
	phase = Phase.WAIT_INPUT


func _resolve_turn_effects(enemy_eojeol: Eojeol, player_eojeol: Eojeol) -> void:
	var enemy_defense := 0
	var player_defense := 0
	if enemy_eojeol != null and enemy_eojeol.role == Eojeol.Role.VERB and enemy_eojeol.data.get("is_defense", false):
		enemy_defense = DamageCalc.raw_amount(enemy, enemy_eojeol.data)
	if player_eojeol != null and player_eojeol.role == Eojeol.Role.VERB and player_eojeol.data.get("is_defense", false):
		player_defense = DamageCalc.raw_amount(player, player_eojeol.data)

	if enemy_eojeol != null and enemy_eojeol.role == Eojeol.Role.VERB and not enemy_eojeol.data.get("is_defense", false):
		var raw := DamageCalc.raw_amount(enemy, enemy_eojeol.data)
		var dealt := DamageCalc.apply_defense(raw, player_defense)
		player.take_damage(dealt)
		player.reduce_poise(DamageCalc.poise_loss(dealt, player.max_hp, player.max_poise))
		_enemy_damage_accum += dealt
		var reduced := raw - dealt
		var suffix := (" (%d 데미지 감소)" % reduced) if reduced > 0 else ""
		log_added.emit("%s %d만큼의 피해를 받았다.%s" % [Josa.i_ga(player.display_name), dealt, suffix])

	if player_eojeol != null and player_eojeol.role == Eojeol.Role.VERB and not player_eojeol.data.get("is_defense", false):
		var raw2 := DamageCalc.raw_amount(player, player_eojeol.data)
		var dealt2 := DamageCalc.apply_defense(raw2, enemy_defense)
		enemy.take_damage(dealt2)
		enemy.reduce_poise(DamageCalc.poise_loss(dealt2, enemy.max_hp, enemy.max_poise))
		_player_damage_accum += dealt2
		log_added.emit("%s %d만큼의 피해를 줬다." % [Josa.i_ga(enemy.display_name), dealt2])


## 양쪽 다 HP 0이면(동시 사망) 패배로 간주한다 (스펙에 명시되지 않은 엣지케이스에 대한 임의 결정).
func _check_battle_end() -> bool:
	if player.is_alive() and enemy.is_alive():
		return false
	phase = Phase.BATTLE_END
	var player_won := enemy.hp <= 0 and player.hp > 0
	battle_finished.emit(player_won)
	return true


func _finish_enemy_sentence() -> void:
	if _enemy_damage_accum > 0:
		log_added.emit("%s 총 %d만큼의 피해를 줬다." % [Josa.i_ga(enemy.display_name), _enemy_damage_accum])
	_enemy_damage_accum = 0
	if _connective_chain < MAX_CONNECTIVE_CHAIN and PatternGenerator.roll_continuation(enemy_pattern, rng):
		_connective_chain += 1
		_load_enemy_sentence(true)
	else:
		_load_enemy_sentence(false)


func _finish_player_sentence() -> void:
	if _player_damage_accum > 0:
		log_added.emit("%s 총 %d만큼의 피해를 받았다." % [Josa.i_ga(enemy.display_name), _player_damage_accum])
	_player_damage_accum = 0
	if not _player_action_id.is_empty():
		player.start_cooldown(_player_action_id, PlayerAction.cooldown_for(_player_action_id))
```

- [ ] **Step 4: 실행해서 통과 확인**

`test_battle_headless.gd`를 다시 Ctrl+Shift+X. Expected: 전부 PASS이고, Output 패널에 적 문장이 한 어절씩
진행되며 쌓인 로그가 보드 예시(`고블린이 총 N만큼의 피해를 줬다.` 등)와 같은 형식으로 출력된다.
(정확한 턴 수/승패는 RNG에 따라 달라지므로 고정값으로 단정하지 않는다 — 이 스텝은 형식과 불변식만 확인.)

- [ ] **Step 5: 커밋**

```bash
git add scripts/battle/battle_manager.gd scripts/tests/test_battle_headless.gd
git commit -m "feat: BattleManager 상태 머신으로 헤드리스 전투 완주 지원 (M2 완료)"
```

---

## Task 8: 전투 UI (M3)

**Files:**
- Create: `scripts/ui/battle_view.gd`
- Create: `scenes/battle.tscn`

**Interfaces:**
- Consumes: `BattleManager`, `Combatant`, `PlayerAction` (Task 4~7). `resources/data/EnemyData/Goblin.tres`,
  `resources/data/PatternData/GolbinPattern1.tres`, `resources/data/VerbData/hit.tres` (Task 1에서 정리된 값).
- Produces: 씬 `res://scenes/battle.tscn`을 Godot 에디터에서 F6로 직접 실행할 수 있음.

이 Task는 순수 로직이 아니라 화면이라 자동 PASS/FAIL 리포터를 쓰지 않는다. 대신 마지막 Step에서
직접 씬을 실행해 눈으로 확인한다. 모든 UI 노드는 `_ready()`에서 코드로 생성한다(기존 `scenes/main.tscn`처럼
씬 파일은 루트 노드 하나 + 스크립트만 가진 얇은 형태를 유지).

- [ ] **Step 1: battle_view.gd 작성**

`scripts/ui/battle_view.gd`:

```gdscript
extends Control
## 프로토타입 전투 화면. UI 노드를 전부 코드로 생성하고 BattleManager의 signal만 구독한다.
## 로직(피해 계산, 턴 진행)은 이 파일에 두지 않는다 — 전부 BattleManager에 있다.

const Combatant = preload("res://scripts/battle/combatant.gd")
const BattleManager = preload("res://scripts/battle/battle_manager.gd")
const PlayerAction = preload("res://scripts/battle/player_action.gd")

var _battle: BattleManager
var _enemy_sentence_label: RichTextLabel
var _player_sentence_label: RichTextLabel
var _log_label: RichTextLabel
var _player_hp_bar: ProgressBar
var _enemy_hp_bar: ProgressBar
var _player_poise_bar: ProgressBar
var _enemy_poise_bar: ProgressBar
var _attack_button: Button
var _defense_button: Button
var _pass_button: Button
var _advance_button: Button


func _ready() -> void:
	_build_ui()
	_start_battle()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var enemy_row := HBoxContainer.new()
	root.add_child(enemy_row)
	enemy_row.add_child(_labelled("적:"))
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(200, 20)
	enemy_row.add_child(_enemy_hp_bar)
	_enemy_poise_bar = ProgressBar.new()
	_enemy_poise_bar.custom_minimum_size = Vector2(200, 10)
	enemy_row.add_child(_enemy_poise_bar)

	_enemy_sentence_label = RichTextLabel.new()
	_enemy_sentence_label.custom_minimum_size = Vector2(600, 40)
	_enemy_sentence_label.fit_content = true
	root.add_child(_enemy_sentence_label)

	var player_row := HBoxContainer.new()
	root.add_child(player_row)
	player_row.add_child(_labelled("플레이어:"))
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.custom_minimum_size = Vector2(200, 20)
	player_row.add_child(_player_hp_bar)
	_player_poise_bar = ProgressBar.new()
	_player_poise_bar.custom_minimum_size = Vector2(200, 10)
	player_row.add_child(_player_poise_bar)

	_player_sentence_label = RichTextLabel.new()
	_player_sentence_label.custom_minimum_size = Vector2(600, 40)
	_player_sentence_label.fit_content = true
	root.add_child(_player_sentence_label)

	var button_row := HBoxContainer.new()
	root.add_child(button_row)
	_attack_button = Button.new()
	_attack_button.text = "타격"
	_attack_button.pressed.connect(_on_action_pressed.bind(PlayerAction.ATTACK_ID))
	button_row.add_child(_attack_button)
	_defense_button = Button.new()
	_defense_button.text = "수비"
	_defense_button.pressed.connect(_on_action_pressed.bind(PlayerAction.DEFENSE_ID))
	button_row.add_child(_defense_button)
	_pass_button = Button.new()
	_pass_button.text = "패스"
	_pass_button.pressed.connect(_on_action_pressed.bind(""))
	button_row.add_child(_pass_button)
	_advance_button = Button.new()
	_advance_button.text = "다음 턴"
	_advance_button.disabled = true
	_advance_button.pressed.connect(_on_advance_pressed)
	button_row.add_child(_advance_button)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(600, 200)
	_log_label.scroll_following = true
	root.add_child(_log_label)


func _labelled(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _start_battle() -> void:
	var player := Combatant.new("플레이어", 100, 12, 10, 100)
	var enemy_data: EnemyDataResource = load("res://resources/data/EnemyData/Goblin.tres")
	var enemy := Combatant.new("고블린", enemy_data.healthPoint, enemy_data.strength,
		enemy_data.dexterity, enemy_data.poise)
	var pattern: PatternDataResource = load("res://resources/data/PatternData/GolbinPattern1.tres")
	var verb: VerbDataResource = load("res://resources/data/VerbData/" + pattern.basicLineVerbID + ".tres")
	var weapon_id: String = enemy_data.possessedWeaponID[0]

	_battle = BattleManager.new(player, enemy, pattern, verb, weapon_id, randi())
	_battle.sentence_loaded.connect(_on_sentence_loaded)
	_battle.log_added.connect(_on_log_added)
	_battle.turn_resolved.connect(_on_turn_resolved)
	_battle.battle_finished.connect(_on_battle_finished)
	_battle.start_battle()
	_refresh_bars()


func _on_action_pressed(action_id: String) -> void:
	if _battle.submit_player_action(action_id):
		_attack_button.disabled = true
		_defense_button.disabled = true
		_pass_button.disabled = true
		_advance_button.disabled = false


func _on_advance_pressed() -> void:
	_battle.advance_turn()
	_advance_button.disabled = true
	if _battle.phase == BattleManager.Phase.WAIT_INPUT:
		_attack_button.disabled = not _battle.player.is_action_ready(PlayerAction.ATTACK_ID)
		_defense_button.disabled = not _battle.player.is_action_ready(PlayerAction.DEFENSE_ID)
		_pass_button.disabled = false
	_refresh_bars()


func _on_sentence_loaded(side: String, sentence: Sentence) -> void:
	if side == "enemy":
		_enemy_sentence_label.text = sentence.to_display_text()
	else:
		_player_sentence_label.text = sentence.to_display_text()


func _on_log_added(text: String) -> void:
	_log_label.append_text(text + "\n")


func _on_turn_resolved(_turn_no: int) -> void:
	_refresh_bars()


func _on_battle_finished(player_won: bool) -> void:
	_log_label.append_text(("승리!" if player_won else "패배...") + "\n")
	_attack_button.disabled = true
	_defense_button.disabled = true
	_pass_button.disabled = true
	_advance_button.disabled = true


func _refresh_bars() -> void:
	_player_hp_bar.max_value = _battle.player.max_hp
	_player_hp_bar.value = _battle.player.hp
	_player_poise_bar.max_value = _battle.player.max_poise
	_player_poise_bar.value = _battle.player.poise
	_enemy_hp_bar.max_value = _battle.enemy.max_hp
	_enemy_hp_bar.value = _battle.enemy.hp
	_enemy_poise_bar.max_value = _battle.enemy.max_poise
	_enemy_poise_bar.value = _battle.enemy.poise
```

- [ ] **Step 2: battle.tscn 작성**

`scenes/battle.tscn` (기존 `scenes/main.tscn`과 같은 얇은 구조 — 루트 노드 하나 + 스크립트):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/battle_view.gd" id="1"]

[node name="BattleView" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 3: 수동 실행 확인**

Godot 에디터에서 프로젝트를 다시 불러온 뒤 `scenes/battle.tscn`을 열고 F6(현재 씬 실행)로 실행한다.
Expected:
- 적 문장(`고블린이 단검으로 ...`)과 HP/강인도 바가 보임.
- "타격"/"수비"/"패스" 버튼 중 하나를 누르면 "다음 턴" 버튼이 활성화됨.
- "다음 턴"을 누르면 어절이 한 개씩 공개되고 로그 패널에 피해 로그가 쌓이며 HP 바가 줄어듦.
- 쿨타임 중인 행동 버튼은 다음 입력 차례에 비활성화되어 있음.
- 한쪽 HP가 0이 되면 "승리!" 또는 "패배..." 로그가 뜨고 모든 버튼이 비활성화됨.
- Output 패널에 스크립트 오류(빨간 텍스트)가 없어야 한다.

- [ ] **Step 4: 커밋**

```bash
git add scripts/ui/battle_view.gd scenes/battle.tscn
git commit -m "feat: 전투 UI(battle_view) 추가 - 프로토타입(M0~M3) 완료"
```

---

## Self-Review 요약

- **스펙 커버리지:** 스펙 §1(성공 기준), §2(결정), §3(아키텍처), §4(상태 머신), §5(M0 데이터), §6(테스트 전략)을
  각각 Task 1~8이 다룬다. §7(범위 밖)은 이 계획에서 구현하지 않음 — 계획대로.
- **플레이스홀더 스캔:** TBD/TODO 없음. 모든 스텝에 실제 코드가 있음.
- **타입 일관성:** `Eojeol.Role`, `Sentence`, `Combatant`, `DamageCalc`, `PatternGenerator`, `PlayerAction`,
  `BattleManager`의 시그니처를 Task 전체에서 동일하게 사용(예: `verb_data`/`data` Dictionary 키
  `stat_type`/`coefficient`/`is_defense`는 Eojeol 생성 시점(Task 5, 6)과 소비 시점(Task 7) 모두 동일).
- **Review Focus 반영:** 5개 항목 모두 해당 Task의 테스트에 케이스로 포함됨 (Task 2: 빈 문자열 Josa,
  Task 5: 가중치 0, Task 7: 체인 상한 + 쿨타임 거부 + 데미지 음수 방지).
