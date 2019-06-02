Plugin.create(:mastodon) do
  # model#scoreを持っている場合のscore_filter
  filter_score_filter do |model, note, yielder|
    next [model, note, yielder] unless model == note
    next [model, note, yielder] unless model.is_a?(Plugin::Mastodon::Status) || model.is_a?(Plugin::Mastodon::AccountProfile) || model.is_a?(Plugin::Mastodon::AccountField)

    if model.score.size > 1 || model.score.size == 1 && !model.score[0].is_a?(Plugin::Score::TextNote)
      yielder << model.score
    end
    [model, note, yielder]
  end
end

