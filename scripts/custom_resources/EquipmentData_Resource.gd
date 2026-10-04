class_name EquipmentData_Resource
extends Resource
## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.

const Rarity = preload("res://scripts/enums/rarity.gd")

## 장비 ID (원본 컬럼: equipmentID)
@export var equipmentID: String = ""

## 아이템 등급 (원본 컬럼: Rarity)
## 값 목록 (res://scripts/enums/rarity.gd): NONE
@export var Rarity: Rarity.Value = Rarity.Value.NONE

## 아이템 효과 숫자 (원본 컬럼: input)
@export var input: Array[float] = []
