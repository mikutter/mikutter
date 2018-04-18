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

  def score_by_score(parent_score)
    score_filter = Enumerator.new{ |y| Plugin.filtering(:score_filter, parent_score, y) }
    selected = min_all(score_filter, &method(:score_order))
    if selected
      selected = max_all(selected, &:count) if selected.size != 1
      Enumerator.new { |yielder|
        selected.first.each do |note|
          if note.is_a? Plugin::Score::TextNote
            score_by_score(note).each(&yielder.method(:<<))
          else
            yielder << note
          end
        end
      }
    else
      [parent_score]
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
