# -*- coding: utf-8 -*-
require_relative 'model/emoji_note'
require_relative 'model/hyper_link_note'
require_relative 'model/text_note'
require_relative 'select'

Plugin.create(:score) do
  # _model_ のdescriptionの値を score_filter に渡して得られるScoreのうち、最も利用に適したものを返す。
  # score_filterの結果を使うのはしんどいので、このメソッドを通して使ったほうが良いよ。
  # ==== Args
  # [model] descriptionメソッドが定義されているオブジェクト (Diva::Model)
  # ==== Return
  # [Enumerable] 内容をModelの配列にしたもの
  defdsl :score_of do |model|
    Plugin::Score.score_by_score(model)
  end

  intent Plugin::Score::HyperLinkNote, label: 'Link Text' do |intent_token|
    forward_to = intent_token.model.reference
    if forward_to
      Plugin.call(:open, forward_to)
    else
      intent_token.forward
    end
  end

  # generic URL
  filter_score_filter do |target_model, note, yielder|
    if target_model != note
      text = note.description
      matched = URI.regexp(%w<http https>).match(text)
      if matched
        score = Array.new
        if matched.begin(0) != 0
          score << Plugin::Score::TextNote.new(
            description: text[0...matched.begin(0)])
        end
        score << Diva::Model(:web).new(perma_link: matched.to_s)
        if matched.end(0) != text.size
          score << Plugin::Score::TextNote.new(
            description: text[matched.end(0)..text.size])
        end
        yielder << score
      end
    end
    [target_model, note, yielder]
  end

  # Entity compat
  filter_score_filter do |target_model, note, yielder|
    if target_model == note && target_model.class.respond_to?(:entity_class) && target_model.class.entity_class && !target_model.links.to_a.empty?
      score = Array.new
      text = target_model.description
      cur = 0
      target_model.links.each do |link|
        range = link[:range]
        if range.first != cur
          score << Plugin::Score::TextNote.new(
            description: text[cur...range.first])
        end
        if link[:open].is_a?(Diva::Model)
          related_model = link[:open]
          uri = link[:open].uri
        else
          related_model = nil
          uri = link[:open] || link[:url]
        end
        score << Plugin::Score::HyperLinkNote.new(
          description: link[:face] || text[range],
          model: related_model,
          uri: uri
        )
        cur = range.last + (range.exclude_end? ? 0 : 1)
      end
      if cur != text.size
        score << Plugin::Score::TextNote.new(
          description: text[cur..text.size])
      end
      yielder << score
    end
    [target_model, note, yielder]
  end
end
