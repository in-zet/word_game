# 문장 기반 턴제 전투 엔진 — 프로토타입 설계 스펙 (M0~M3)

- 상태: 사용자 검토 대기
- 범위: `docs/GAME_PLAN.md`의 마일스톤 중 **M0(데이터 정리) ~ M3(전투 UI)**. 프로토타입에서 "어절 = 턴" 전투가
  재미있는지 검증하는 것이 목표. M4(Effect/그로기) 이후는 별도 스펙/계획으로 이어감.
- 출처: FigJam 보드 「텍스트 기반 로그라이크 RPG」 + `docs/GAME_PLAN.md`의 정리 내용.

## 1. 목표와 성공 기준

플레이어가 고블린 1마리와 전투를 완주할 수 있다:
- 고블린의 공격이 `고블린이 [단검으로] [빠르게] 찌른다.` 형태의 문장으로, 한 어절씩 턴 단위로 진행된다.
- 플레이어는 각 턴에 타격/수비를 입력하고, 입력한 행동도 같은 방식의 문장(`방패로 막는다.`)으로 진행된다.
- 서술어 어절이 해소되는 턴에 피해/방어가 실제로 계산되고, 문장이 끝나면 `"고블린이 총 N만큼의 피해를 줬다."`
  형식으로 로그가 남는다.
- 전투 UI에서 적 문장, 플레이어 문장, 로그, 쿨타임 상태를 확인하며 승리/패배까지 진행할 수 있다.

## 2. 확정된 설계 결정

이전 라운드에서 사용자 확인을 받은 항목:

| 항목 | 결정 |
|---|---|
| 강인도 감소 계수 | 직접 피해가 **최대체력의 50%**일 때 강인도가 전부 깎이도록: `poise_loss = deal / maxHp * maxPoise * 2` |
| 턴 진행 방식 | **스텝 모드** — 입력/버튼으로 한 어절씩 수동 진행 (M4 이후 실시간 타이머 모드 옵션 추가 가능하도록 인터페이스는 분리) |
| 문장 공개 범위 | **기본 문장은 시작 시 전체 미리 공개**. **이어진 문장은 실제로 생성되는 시점(기본 문장 종료 후 확률 판정)까지는 미공개** — 애초에 확률로 결정되므로 미리 보여줄 수 없음 |

이번 스펙 작성 과정에서 제가 정한 나머지 항목 (근거 포함, 이견 있으면 알려주세요):

| 항목 | 결정 | 근거 |
|---|---|---|
| 피해 발생 시점 | 서술어(V) 어절이 해소되는 **턴에 실제 계산**, 로그의 합산 문구는 **문장 종료 시** 출력 | 플로우차트의 "결과 계산"은 매 턴에 있고, 보드 예시 로그(`총 N만큼`)는 문장 종료 시 나타남 — 두 소스를 그대로 반영 |
| 선딜(1턴)의 의미 | 플레이어가 행동을 입력하면 그 행동 문장의 **첫 어절(부사어, 예: `방패로`)이 선딜 턴**이고, 서술어 어절(`막는다.`)에서 실제 효과가 발동 — 적 서술어와 동일한 처리 방식 | 적 문장과 동일한 어절/턴 모델을 플레이어에게도 적용해 로직을 하나로 통일 |
| 플레이어 문장 생성 규칙 | 프로토타입에서는 패턴 생성기(2.4 문법 규칙)를 적용하지 않고 **타격 = `[STR스탯]으로 때렸다.` 서술어 1개, 수비 = `[DEX스탯]로 막았다.` 서술어 1개**의 고정 2문장만 사용 | 보드의 프로토타입 스펙에 플레이어 행동은 2개뿐이고 확장 문법 언급이 없음 — YAGNI, M5(패턴 생성기)에서 적에게만 우선 적용 후 필요시 확장 |
| 주어 조사 | 전부 **"고블린이"(이/가)로 통일** | 보드에 `이/가`와 `은/는`이 혼재하지만 `이/가` 쪽 용례가 더 많고, `haveBatchim` 필드가 이미 이/가·을/를류 받침 규칙을 전제로 설계됨 |

## 3. 아키텍처

전투 로직은 UI와 분리된 순수 GDScript(`RefCounted`)로 작성하고, 씬은 시그널로 결과만 받아 그린다.
헤드리스로 콘솔에서 전투 1턴~완주까지 돌려볼 수 있어야 한다 (M2 완료 기준).

```
scripts/
├── DB/ , custom_resources/ , enums/     (기존, M0에서 데이터만 정리)
├── core/
│   ├── data_registry.gd      [Autoload] id -> Resource 조회 (resources/data/** 스캔, 캐싱)
│   └── josa.gd                조사/어미 유틸: 이/가, 은/는, 으로/로, 받침 판정 (유니코드 (code-0xAC00)%28==0)
├── battle/
│   ├── eojeol.gd              어절 1개: role(주어/부사어/서술어/시스템), text, source_data, owner_verb_index
│   ├── sentence.gd            어절 배열 + 커서. next()/is_finished()/cancel_rest()
│   ├── combatant.gd           HP, 강인도, STR/DEX, 쿨타임 dict, 행동 가능 여부
│   ├── pattern_generator.gd   PatternData -> 적 Sentence 생성 (기본 문장 전체 + 이어진 문장은 지연 생성)
│   ├── player_action.gd       타격/수비 입력 -> 고정 템플릿 Sentence 생성
│   ├── damage_calc.gd         피해량, 방어 차감, 강인도 감소 계산 (순수 함수 위주)
│   └── battle_manager.gd      §4 상태 머신. signal로 결과 발행, Combatant/Sentence를 갖고 진행
└── ui/
    ├── battle_view.gd         적 문장 어절 카드(공개/비공개), 플레이어 문장 줄, HP/강인도 바, 행동 버튼, 로그 패널
    └── (battle_view가 battle_manager의 signal을 구독해서만 그림 — 로직 직접 호출 없음)
scenes/
└── battle.tscn                battle_view + battle_manager 노드 구성, 현재 main.tscn 대체 또는 하위 씬으로 로드
```

의존 방향: `ui` → `battle` → `core`/`custom_resources`. 역방향 참조 없음 (battle_manager는 Node를 모름).

## 4. BattleManager 상태 머신 (스텝 모드)

```
BATTLE_START
  → LOAD_SENTENCE      (pattern_generator로 적 Sentence 확정, 기본 문장 전체 공개)
  → SENTENCE_LOOP:
      WAIT_INPUT        (플레이어 입력 대기: 타격/수비/패스 — 쿨타임 중이면 해당 버튼 비활성)
        → advance_turn() 호출로 진행
      TURN_RESOLVE:
        1. 이번 턴에 해소되는 적/플레이어 어절 각각 apply()
        2. 서술어 어절이면 damage_calc로 피해/강인도 계산, Combatant에 반영
        3. 로그 이벤트 발행 (log_added)
        4. 유저 강인도 <= 0 ? → 유저 이후 어절 취소 + 경직 부여 (M4에서 실제 effect 연결, M3에서는 훅만)
        5. 적 강인도 <= 0 ? → 적 이후 어절 취소, 그로기 문장 예약 (M4)
        6. 전투 종료 판정 (HP <= 0) → BATTLE_END
        7. 아니면 다음 턴으로 (커서 증가)
      → 문장 종료? NO → WAIT_INPUT 반복
                    YES → 문장 종료 로그(합산 피해) → 이어진 문장 확률 판정
                          → YES: 이어진 문장 생성 후 SENTENCE_LOOP 계속
                          → NO: LOAD_SENTENCE (다음 문장)
  → BATTLE_END (승/패 signal 발행)
```

시그널: `sentence_loaded(sentence)`, `eojeol_revealed(side, index)`, `log_added(text)`,
`turn_resolved(turn_no)`, `battle_finished(result: bool)`.

`submit_player_action(action_id)`는 `WAIT_INPUT` 상태이고 쿨타임이 끝난 행동에 대해서만 수락한다.
행동을 입력하지 않고 그냥 턴을 넘기는 것(패스)도 허용한다.

## 5. 데이터 정리 범위 (M0)

- enum 5종(`AdverbType`, `RangeType`, `StatType`, `TriggerTimingType`, `DecayType`)에 실제 값 채우기.
  프로토타입에 필요한 최소 값만: `AdverbType = {MEANS, MANNER}`, `StatType = {STR, DEX}`.
  `RangeType`, `TriggerTimingType`, `DecayType`은 M4에서 채움 (M3까지는 미사용).
- `AdverbData`: `dagger`(단검으로, MEANS), `fast`(빠르게, MANNER)에 `adverbType` 채우기. `강하게`, `방패로`
  등 프로토타입 패턴 2·3에 필요한 부사어는 M0에서 시트에 추가하지 않고, 코드에서는 패턴 1(`단검으로 빠르게 찌른다`)
  만 우선 지원 — 패턴 2/3은 이어진 문장·관형어 기능(M5) 전에는 테스트 데이터로만 존재.
- `EnemyData/Goblin`: 보드 프로토타입 스펙대로 STR 8 / DEX 6으로 수정.
- `PatternData`: `appearableVerbWeight`를 `[0]` → `[1]`로 수정해 이어진 문장이 실제로 뽑히도록 함.
- 오타 수정은 **하지 않음**: `charmisma`, `addtionalCreatedAdverb`, `Golbin`은 시트(외부) 쪽 컬럼명이라
  이번 스코프에서 건드리면 시트-코드 동기화가 깨짐. 별도 작업으로 분리.

## 6. 테스트 전략

- `battle/` 아래 순수 로직은 GUT(Godot Unit Test) 또는 `EditorScript` 기반 스크립트 테스트로 검증
  (레포에 아직 테스트 프레임워크 없음 — M0에서 GUT addon 도입 여부를 계획 단계에서 결정).
- 최소 커버리지: `josa.gd`(받침 판정 표 기반), `damage_calc.gd`(기본/방어 차감/강인도), `sentence.gd`(커서 진행/취소),
  `pattern_generator.gd`(패턴 1 문장이 규칙대로 어절 배열을 만드는지).
- M2 완료 기준: 헤드리스 스크립트로 `플레이어 vs 고블린(패턴1)` 1전을 자동 진행시켜 로그 출력이 보드 예시와
  같은 형식인지 콘솔에서 확인.

## 7. 범위 밖 (다음 스펙으로 이연)

- Effect 시스템(출혈/중독/화상/경직/마력 탈진) 실제 발동 로직 — M4.
- 관형어, 이어진 문장의 접속 규칙(와/과, ~고), 부사어 충돌·연결어미 — M5 패턴 생성기 고도화.
- 탐험/선택지/이벤트 코어 루프, 보상/성장 — M6.
- 실시간 타이머 턴 모드 — 스텝 모드로 UX 검증 후 필요하면 추가.
