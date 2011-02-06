# -*- coding: utf-8 -*-

require 'gtk2'
miquire :mui, 'extension'

module Gtk::MumbleVote

  def self.def_voter(voter, short_name)
    # VOTEしたユーザの配列
    by = define_method("#{voter}_by"){ @votebuf ||= [] }

    box = define_method("#{voter}_box"){
      @vote_box ||= {}
      @vote_box[voter] ||= Gtk::HBox.new(false, 0) }

    label = define_method("#{voter}_label"){
      @vote_label ||= {}
      @vote_label[voter] ||= Gtk::Label.new('').set_no_show_all(true) }

    gen = define_method("gen_#{voter}"){
      @gen_voter ||= {}
      @gen_voter[voter] ||= Gtk::HBox.new(false, 4).closeup(instance_eval(&label)).closeup(instance_eval(&box)).right }

    # _user_ にvoteされたことにする。
    # votebufにユーザを格納し、レンダリングする。
    define_method("on_#{voter}"){ |user|
      mainthread_only
      if(UserConfig[:"#{voter}_by_anyone_show_timeline"])
        type_strict user => User
        if(not instance_eval(&box).destroyed?) and (not instance_eval(&by).include?(user))
          instance_eval(&box).closeup(Gtk::EventBox.new.add(icon(user, 24)).tooltip(user[:idname]).show_all)
          instance_eval(&by) << user
          __send__("rewind_#{voter}_count!") end end }

    # ラベルの数字を書き換える。
    define_method("rewind_#{voter}_count!"){
      mainthread_only
      return if(instance_eval(&box).destroyed?)
      if(instance_eval(&box).children.size == 0)
        instance_eval(&label).hide_all.set_no_show_all(true)
      else
        instance_eval(&label).set_text("#{instance_eval(&by).size} #{short_name} ").set_no_show_all(false).show_all
      end
    }

    define_method("#{voter}_packer"){
      unless instance_eval(&by).empty?
        Delayer.new(Delayer::NORMAL){
          if(not destroyed?)
            instance_eval(&by).each{ |user| __send__("on_#{voter}", user) }
            instance_eval(&gen).show_all end } end }

  end

  def_voter :favorited, 'Fav'
  def_voter :retweeted, 'RT'

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
