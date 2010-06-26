miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

module Addon
  class SetInput < Addon

    include SettingUtils

    def onboot(watch)
      container = self.main(watch)
      Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, container, '入力'])
    end

    def onplugincall(watch, command, *args)
      case command
      when :regist_url_shrinker_setting
        shrink_url.child.add(gen_expander(args[0], false, args[1])).show_all
      end
    end

    def main(watch)
      Gtk::VBox.new(false, 8).
        closeup(gen_keyconfig('つぶやきを投稿するキー', :mumble_post_key)).
        closeup(gen_adjustment('投稿をリトライする回数', :message_retry_limit, 1, 99)).
        closeup(shrink_url).
        closeup(gen_group('フッタ',
                          gen_input('デフォルトで挿入するフッタ', :footer)[0],
                          gen_boolean(:footer_exclude_reply, 'リプライの場合はフッタを付与しない'),
                          gen_boolean(:footer_exclude_retweet, '引用(非公式ReTweet)の場合はフッタを付与しない')))
    end

    def shrink_url
      return @shrink_url if @shrink_url
      @shrink_url = gen_group('短縮URL',
                              gen_boolean(:shrinkurl_always, '常にURLを短縮する')) end end end

Plugin::Ring.push Addon::SetInput.new,[:boot, :plugincall]
