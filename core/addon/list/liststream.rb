# -*- coding: utf-8 -*-
# リストをリアルタイム化

Plugin::create(:liststream) do

  on_list_member_changed do |userlist|
    Plugin.call(:filter_stream_force_retry) end

  filter_filter_stream_follow do |member|
    [member + member_anything_and_not_following] end

  # 表示対象のListのうち、いずれかに所属するUserを含んだEnumerableを返す。
  # 呼ぶたびにフィルタを利用するので負荷が高いため、注意する。
  def member_anything
    Plugin.filtering(:displayable_lists, Set.new).first.inject(Set.new) { |member, list|
      if list
        member + list[:member]
      else
        member end } end

  # _member_anything_ のうち、自分がフォローしているユーザを除くUserを含んだEnumerableを返す。
  def member_anything_and_not_following
    member_anything - Plugin.filtering(:followings, Set.new).first end

end

