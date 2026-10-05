class_name BehaveState
extends Node

var target_character: Character
var data_dict: Dictionary[RangeType.Value, BehaveStateData] = {
	RangeType.Value.TEXT: BehaveStateData.new(),
	RangeType.Value.LINE: BehaveStateData.new(),
}


func execute(word: BaseWord):
	if word is Adverb:
		var av_word_data: AdverbDataResource = word.data
		var target_data: BehaveStateData = data_dict[av_word_data.modifyRange]
		
		# target_data에 av_word.data랑 더하기 
		
		match av_word_data.adverbType:
			AdverbType.Value.NONE:
				target_data.coef_modifier += av_word_data.coefficient
