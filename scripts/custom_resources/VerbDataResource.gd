class_name VerbDataResource
extends Resource
## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.

const StatType = preload("res://scripts/enums/stat_type.gd")

## 서술어 ID (원본 컬럼: verbID)
@export var verbID: String = ""

## 적용되는 능력치 (원본 컬럼: statBonusType)
## 값 목록 (res://scripts/enums/stat_type.gd): NONE
@export var statBonusType: StatType.Value = StatType.Value.NONE

## 적용 능력치 계수 (원본 컬럼: statBonusValue)
@export var statBonusValue: float = 0.0

## 받침 여부 (원본 컬럼: haveBatchim)
@export var haveBatchim: bool = false

## 쿨타임 (원본 컬럼: coolDownTurn)
@export var coolDownTurn: int = 0

## 시전자에게 적용되는 디버프 ID (원본 컬럼: appliedEffectID)
@export var appliedEffectID: Array[String] = []

## 시전자에게 적용되는 디버프 수치 (원본 컬럼: appliedEffectValue)
@export var appliedEffectValue: Array[float] = []

## 강인도 피해 배율 (원본 컬럼: poiseDamageRate)
@export var poiseDamageRate: float = 0.0
