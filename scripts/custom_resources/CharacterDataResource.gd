class_name CharacterDataResource
extends Resource
## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.

## 적 ID (원본 컬럼: characterID)
@export var characterID: String = ""

## 근력 (원본 컬럼: strength)
@export var strength: int = 0

## 민첩 (원본 컬럼: dexterity)
@export var dexterity: int = 0

## 지능 (원본 컬럼: intelligence)
@export var intelligence: int = 0

## 매력 (원본 컬럼: charmisma)
@export var charmisma: int = 0

## 체력 (원본 컬럼: healthPoint)
@export var healthPoint: int = 0

## 강인도 (원본 컬럼: poise)
@export var poise: int = 0

## 회피율 (원본 컬럼: avoid)
@export var avoid: float = 0.0

## 치명타확률 (원본 컬럼: criticalRate)
@export var criticalRate: float = 0.0

## 치명타피해 (원본 컬럼: criticalDamage)
@export var criticalDamage: float = 0.0

## 생명력 흡수 (원본 컬럼: lifeSteal)
@export var lifeSteal: float = 0.0

## 보유 패턴 ID (원본 컬럼: patternID)
@export var patternID: Array[String] = []

## 보유 패턴 가중치 (원본 컬럼: patternWeight)
@export var patternWeight: Array[int] = []

## 보유 무기 ID (원본 컬럼: weaponID)
@export var weaponID: Array[String] = []
