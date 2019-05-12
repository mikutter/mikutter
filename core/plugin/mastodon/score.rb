Plugin.create(:mastodon) do
  pm = Plugin::Mastodon

  # model#scoreを持っている場合のscore_filter
  filter_score_filter do |model, note, yielder|
    next [model, note, yielder] unless model == note
    next [model, note, yielder] unless (model.is_a?(pm::Status) || model.is_a?(pm::AccountProfile))

    if model.score.size > 1 || model.score.size == 1 && !model.score[0].is_a?(Plugin::Score::TextNote)
      yielder << model.score
    end
    [model, note, yielder]
  end
end

