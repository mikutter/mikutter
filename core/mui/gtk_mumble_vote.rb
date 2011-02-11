# -*- coding: utf-8 -*-

require 'gtk2'
miquire :mui, 'extension'

=begin rdoc
  includeすると、
=end
module Gtk::MumbleVote

  def self.included(includer)
    includer.extend(Voter)
  end

  module Voter
    def define_voter(voter, short_name)
      # VOTEしたユーザの配列

      by = define_method("#{voter}_by"){
        @votebuf ||= Hash.new
        @votebuf[voter] ||= [] }

      box = define_method("#{voter}_box"){
        @vote_box ||= Hash.new
        @vote_box[voter] ||= Gtk::HBox.new(false, 0) }

      label = define_method("#{voter}_label"){
        @vote_label ||= Hash.new
        @vote_label[voter] ||= Gtk::Label.new('').set_no_show_all(true) }

      gen = define_method("gen_#{voter}"){
        @gen_voter ||= Hash.new
        @gen_voter[voter] ||= Gtk::HBox.new(false, 4).closeup(__send__("#{voter}_label")).closeup(__send__("#{voter}_box")).right }

      # _user_ にvoteされたことにする。
      # votebufにユーザを格納し、レンダリングする。

      define_method("on_#{voter}"){ |user|
        mainthread_only
        if(UserConfig[:"#{voter}_by_anyone_show_timeline"])
        type_strict user => User
        if(not __send__("#{voter}_box").destroyed?) and (not __send__("#{voter}_by").include?(user))
          __send__("#{voter}_box").closeup(Gtk::EventBox.new.add(icon(user, 24)).tooltip(user.idname).show_all)
          __send__("#{voter}_by") << user
          __send__("rewind_#{voter}_count!") end end }

      # ラベルの数字を書き換える。
      define_method("rewind_#{voter}_count!"){
        mainthread_only
        return if(__send__("#{voter}_box").destroyed?)
        if(__send__("#{voter}_box").children.size == 0)
          __send__("#{voter}_label").hide_all.set_no_show_all(true)
        else
          __send__("#{voter}_label").set_text("#{__send__("#{voter}_by").size} #{short_name} ").set_no_show_all(false).show_all
        end
      }

      define_method("#{voter}_packer"){
        unless __send__("#{voter}_by").empty?
          Delayer.new(Delayer::NORMAL){
            if(not destroyed?)
              __send__("#{voter}_by").each{ |user| __send__("on_#{voter}", user) }
              __send__("gen_#{voter}").show_all end } end }
    end
  end

  def on_unfavorited(user)
    # mainthread_only
    # if(UserConfig[:favorited_by_anyone_show_timeline])
    #   idx = favorited_by.index(user)
    #   if idx
    #     favorited_by.delete_at(idx)
    #     fav_box.remove(fav_box.children[idx])
    #     rewind_fav_count! end end
  end

  private

  def gen_vote_button(user)
    mainthread_only
    result = Gtk::EventBox.new.add(icon(user, 24)).tooltip(user[:idname])
    result.events = Gdk::Event::POINTER_MOTION_MASK | Gdk::Event::BUTTON_PRESS_MASK
    result.signal_connect(:'button-release-event'){
      Plugin.call(:show_profile, (@message.service or Post.primary_service), user) }
    result
  end

end
