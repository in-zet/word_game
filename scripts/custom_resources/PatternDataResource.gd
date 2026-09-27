class_name PatternDataResource
extends Resource
## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.

## 패턴 ID (원본 컬럼: PatternID)
@export var PatternID: String = ""

## 기본 문장의 주어 (원본 컬럼: basicLineSubject)
@export var basicLineSubject: String = ""

## 기본 문장의 서술어 ID (원본 컬럼: basicLineVerbID)
@export var basicLineVerbID: String = ""

## 부사어 등장 확률 (원본 컬럼: adverbAppearRate)
@export var adverbAppearRate: float = 0.0

## 등장 가능한 부사어 ID (원본 컬럼: appearableAdverbID)
@export var appearableAdverbID: Array[String] = []

## 등장 가능한 부사어 가중치 (원본 컬럼: appearableAdverbWeight)
@export var appearableAdverbWeight: Array[int] = []

## 이어진 서술어 등장 확률 (원본 컬럼: verbAppearRate)
@export var verbAppearRate: float = 0.0

## 등장 가능한 이어진 서술어 ID (원본 컬럼: appearableVerbID)
@export var appearableVerbID: Array[String] = []

## 등장 가능한 이어진 서술어 가중치 (원본 컬럼: appearableVerbWeight)
@export var appearableVerbWeight: Array[int] = []
