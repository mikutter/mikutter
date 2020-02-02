# -*- coding: utf-8 -*-

module Plugin::Score
  extend self

  def score_by_score(model, target_note=model)
    @score_cache ||= TimeLimitedStorage.new(Array, Object, 60)
    @score_cache[[model, target_note]] ||= score_by_score_nocache(model, target_note).to_a.freeze
  end

  def score_by_score_nocache(model, target_note=model)
    _, _, available_score_list = Plugin.filtering(:score_filter, model, target_note, Set.new)
    selected_score = choose_best_score(available_score_list)
    if selected_score && !selected_score.all? { |s| s.is_a?(Plugin::Score::TextNote) }
      score_expand(selected_score, model)
    elsif target_note.is_a?(Plugin::Score::TextNote)
      [target_note]
    else
      score_by_score(model, Plugin::Score::TextNote.new(description: model.description))
    end
  end

  # _score_list_ の中から、利用すべきScoreをひとつだけ返す。
  # 一つも該当するものがない場合は nil を返す。複数該当する場合は、結果は不定。
  def choose_best_score(score_list)
    selected = max_score_count(smallest_leading_text_size(score_list))
    selected.first
  end

  # 最初にTextNote以外が出てくるまでに出てきたTextNoteのdescriptionの文字数の合計が少ないもののみを列挙する。
  def smallest_leading_text_size(score_list)
    min_all(score_list, &method(:leading_text_size))
  end

  # Scoreを構成するNoteの数が一番多いもののみを列挙する。
  def max_score_count(score_list)
    max_all(score_list, &:count)
  end

  private

  def score_expand(score, model)
    score.flat_map do |note|
      if note.is_a? Plugin::Score::TextNote
        score_by_score(model, note)
      else
        [note]
      end
    end
  end

  def leading_text_size(score)
    score.inject(0) do |index, note|
      if note.is_a?(Plugin::Score::TextNote)
        index + note.description.size
      else
        break index
      end
    end
  end

  def min_all(list, &proc)
    return list if list.size <= 1
    order = Hash.new{|h,k| h[k] = proc.(k) }
    _, result = list.sort_by{|node|
      order[node]
    }.chunk{|node|
      order[node]
    }.first
    result
  end

  def max_all(list, &proc)
    min_all(list){|x| -proc.(x) }
  end
end
