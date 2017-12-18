# -*- coding: utf-8 -*-

require_relative 'userlist'
require_relative 'sender'
require_relative 'dmlistview'

module Plugin::DirectMessage
  Plugin.create(:direct_message) do
    @counter = gen_counter

    Delayer.new do
      refresh_tab
      interval
    end

    on_world_create do |world|
      refresh_tab
    end

    on_world_destroy do |world|
      refresh_tab
    end

    def refresh_tab
      if Enumerator.new{|y| Plugin.filtering(:worlds, y) }.any?{|w| w.class.slug == :twitter }
        present_tab
      else
        absent_tab
      end
    end

    def present_tab
      @tag ||= handler_tag do
        userlist = UserList.new
        tab(:directmessage, _("DM")) do
          set_icon Skin['directmessage.png']
          expand
          nativewidget userlist
        end

        on_direct_messages do |_, dms|
          dm_distribution = Hash.new {|h,k| h[k] = []}
          dms.each do |dm|
            model = Plugin::Twitter::DirectMessage.new_ifnecessary(dm)
            dm_distribution[model[:user]] << model
            dm_distribution[model[:recipient]] << model
          end
          dm_distribution.each do |to_user, dm_for_user|
            Plugin::GUI::Timeline.instance(timeline_name_for(to_user)) << dm_for_user
            Plugin.call :extract_receive_message, timeline_name_for(to_user), dm_for_user
          end
          Plugin.call :extract_receive_message, :direct_message, dms
          userlist.update(dm_distribution.map{|k, v| [k, v.map{|dm| dm[:created]}.max]}.to_h)
        end

        filter_extract_datasources do |datasources|
          datasources = {
            direct_message: _("ダイレクトメッセージ"),
          }.merge datasources
          Enumerator.new{|y|
            Plugin.filtering(:worlds, y)
          }.lazy.select{|world|
            world.class.slug == :twitter
          }.map(&:user_obj).each{ |user|
            datasources.merge!({ extract_slug_for(user) => "@#{user.idname}/" + _("ダイレクトメッセージ") })
          }
          [datasources]
        end
      end
    end

    def absent_tab
      if @tag
        tab(:directmessage).destroy
        detach(@tag)
        @tag = nil
      end
    end

    user_fragment(:directmessage, _("DM")) do
      set_icon Skin['directmessage.png']
      u = model
      timeline timeline_name_for(u) do
        postbox(to: u, delegate_other: true, visibility: :direct)
      end
    end

    def extract_slug_for(user)
      "direct_message-#{user.id}".to_sym
    end

    def timeline_name_for(user)
       :"direct_messages_from_#{user.idname}"
    end

    def interval
      Reserver.new([60, (UserConfig[:retrieve_interval_direct_messages] || 1).to_i * 60].max, thread: Delayer) do
        interval
        Enumerator.new{|y|
          Plugin.filtering(:worlds, y)
        }.lazy.select{|w| w.class.slug == :twitter }.each(&method(:rewind))
      end
    end

    def rewind(world)
      Deferred.when(
        world.direct_messages(cache: :keep),
        world.sent_direct_messages(cache: :keep)
      ).next{ |dm, sent|
        result = dm + sent
        Plugin.call(:direct_messages, world, result) unless result.empty?
      }.terminate.trap{ |err|
        error e
      }
    end
  end
end
