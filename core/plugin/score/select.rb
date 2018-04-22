# -*- coding: utf-8 -*-

module Plugin::Score
  extend self

  def score_order(score)
    score.inject(0) do |index, note|
      if note.is_a?(Plugin::Score::TextNote)
        index + note.description.size
      else
        break index
      end
    end
  end

  def score_by_score(model, target_note=model)
    score_filter = Enumerator.new{ |y| Plugin.filtering(:score_filter, model, target_note, y) }
    selected = min_all(score_filter, &method(:score_order))
    if selected
      selected = max_all(selected, &:count) if selected.size != 1
      Enumerator.new { |yielder|
        selected.first.each do |note|
          if note.is_a? Plugin::Score::TextNote
            score_by_score(model, note).each(&yielder.method(:<<))
          else
            yielder << note
          end
        end
      }
    elsif target_note.is_a?(Plugin::Score::TextNote)
      [target_note]
    else
      score_by_score(model, Plugin::Score::TextNote.new(description: model.description))
    end
  end

  def min_all(list, &proc)
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
