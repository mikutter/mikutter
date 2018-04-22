Plugin.create(:worldon) do
  pm = Plugin::Worldon

  # <a>タグをHyperLinkNoteにするフィルタ
  filter_score_filter do |model, note, yielder|
    if model.is_a?(pm::Status) && model == note && model.score.size > 1
      yielder << model.score
    end
    [model, note, yielder]
  end

  # カスタム絵文字をEmojiNoteにするフィルタ
  filter_score_filter do |model, note, yielder|
    if model.is_a?(pm::Status)
      model.dictate_emoji(note.description, yielder)
    end
    [model, note, yielder]
  end

  # TODO: 添付画像を付加するscore_filter
  # TODO: Toot URLを引用tootにするscore_filter
  # TODO: acctをPlugin::Worldon::AccountとしてopenできるNoteにするscore_filter
end

