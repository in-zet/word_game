class_name EffectDataResource
extends Resource
## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.

const TriggerTimingType = preload("res://scripts/enums/trigger_timing_type.gd")
const DecayType = preload("res://scripts/enums/decay_type.gd")

## Effect ID (원본 컬럼: effectID)
@export var effectID: String = ""

## 발동 시점 (원본 컬럼: triggerTiming)
## 값 목록 (res://scripts/enums/trigger_timing_type.gd): ON_VERB, TURN_INTERVAL, SENTENCE_END, TURN_START
@export var triggerTiming: TriggerTimingType.Value = TriggerTimingType.Value.ON_VERB

## 발동시 감소 방식 (원본 컬럼: decayType)
## 값 목록 (res://scripts/enums/decay_type.gd): NONE, MINUS_ONE, HALVE
@export var decayType: DecayType.Value = DecayType.Value.NONE

## 발동 주기 (원본 컬럼: interval)
@export var interval: int = 0
