Plugin.create(:worldon) do
  pm = Plugin::Worldon

  # <a>タグをHyperLinkNoteにするフィルタ
  filter_score_filter do |parent_score, yielder|
    model = parent_score.ancestor
    if model.is_a?(pm::Status) && model.description == parent_score.description && model.score.size > 1
      pp model.score
      yielder << model.score
    end
    [parent_score, yielder]
  end

  # カスタム絵文字をEmojiNoteにするフィルタ
  filter_score_filter do |parent_score, yielder|
    model = parent_score.ancestor
    if model.is_a?(pm::Status)
      model.dictate_emoji(parent_score.description, yielder)
    end
    [parent_score, yielder]
  end

  # TODO: 添付画像を付加するscore_filter
  # TODO: Toot URLを引用tootにするscore_filter
  # TODO: acctをPlugin::Worldon::AccountとしてopenできるNoteにするscore_filter
end

