class_name BehaveState
extends Node

var target_character: Character
var data_dict: Dictionary[RangeType.Value, BehaveStateData] = {
	RangeType.Value.TEXT: BehaveStateData.new(),
	RangeType.Value.LINE: BehaveStateData.new(),
}


func reset_behave_state(type: RangeType.Value):
	data_dict[type] = BehaveStateData.new()


func execute(word: BaseWord):
	if word is Adverb:
		var av_word_data: AdverbDataResource = word.data
		var target_data: BehaveStateData = \
			data_dict[av_word_data.modifyRange]
		
		# target_data에 av_word.data랑 더하기 
		
		match av_word_data.adverbType:
			AdverbType.Value.NONE:
				pass

			AdverbType.Value.TRUE_DAMAGE:
				target_data.truedmg_modifier += av_word_data.coefficient

			AdverbType.Value.PERCENT_POINT:
				target_data.pp_modifier += av_word_data.coefficient

			AdverbType.Value.CRIT_RATE:
				target_data.critr_modifier += av_word_data.coefficient

			AdverbType.Value.EFFECT:
				target_data.effect_modifier.append(
					[av_word_data.appliedEffectID,
					 av_word_data.appliedEffectValue]
				)  # WIP!!!!!!!

			AdverbType.Value.PATTERN_MOD:
				pass

			
