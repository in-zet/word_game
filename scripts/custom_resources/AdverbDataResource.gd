class_name AdverbDataResource
extends Resource
## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.

const AdverbType = preload("res://scripts/enums/adverb_type.gd")
const RangeType = preload("res://scripts/enums/range_type.gd")

## 부사어 ID (원본 컬럼: adverbID)
@export var adverbID: String = ""

## 부사어 Type (원본 컬럼: adverbType)
## 값 목록 (res://scripts/enums/adverb_type.gd): NONE
@export var adverbType: AdverbType.Value = AdverbType.Value.NONE

## 적용 계수 (원본 컬럼: coefficient)
@export var coefficient: float = 0.0

## 수식 범위 (원본 컬럼: modifyRange)
## 값 목록 (res://scripts/enums/range_type.gd): NONE
@export var modifyRange: RangeType.Value = RangeType.Value.TEXT

## 중복 불가 부사어 ID (원본 컬럼: conflictingAdverb)
@export var conflictingAdverb: Array[String] = []

## 생성시 필요 부사어 ID (원본 컬럼: requirementAdverb)
@export var requirementAdverb: Array[String] = []

## 추가 생성 부사어 ID (원본 컬럼: addtionalCreatedAdverb)
@export var addtionalCreatedAdverb: Array[String] = []

## 대상에게 적용되는 디버프 ID (원본 컬럼: appliedEffectID)
@export var appliedEffectID: Array[String] = []

## 대상에게 적용되는 디버프 수치 (원본 컬럼: appliedEffectValue)
@export var appliedEffectValue: Array[float] = []

## 받침 여부 (원본 컬럼: haveBatchim)
@export var haveBatchim: bool = false
