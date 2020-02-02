# -*- coding: utf-8 -*-

Plugin.create :guide do
  # 茶番オブジェクトを新しく作る
  def sequence
    # 茶番でしか使わないクラスなので、チュートリアル時だけロードする
    require_relative 'interactive'
    Plugin::Guide::Interactive.generate end

  @sequence = {}

  def defsequence(name, &content)
    @sequence[name] = content end

  def jump_seq(name)
    if defined? @sequence[name]
      store(:guide_sequence, name)
      if @sequence.has_key? name
        @sequence[name].call
      else
        @sequence[:first].call
      end end end

  def guide_start(ach)
    tab :guide, _('World ガイド') do
      set_icon Skin[:icon]
      timeline(:guide)
    end

    on_finish_guide do |world|
      ach.take!
    end

    seq = at(:guide_sequence)
    case seq
    when nil, :first
      jump_seq(:first)
    else
      sequence.
        say(_("前回の続きから説明するね")).
        next{ jump_seq(seq) }
    end
  end

  defsequence :first do
    sequence.
      say(_('おーい、こっちこっち。'))
    focus_observer = on_gui_child_activated do |parent, child, by_toolkit|
      if parent == tab(:guide)
        detach(focus_observer)
        sequence.next{
          Thread.new{ sleep 1 }
        }.prompt(_('そうそれ！')).
          prompt(_('こんにちは。私はみくったーちゃん！チュートリアルしか出番がないマスコットキャラクターだよ！')).
          prompt(_("あなたはmikutterは初めて？"),
                 _('初めて（チュートリアルを見る）') => :guide_start,
                 _('完全に理解してる（チュートリアルをスキップ）') => :skip).
          next { |selected|
        jump_seq selected
        }
      end
    end
  end

  defsequence :guide_start do
    world_dict, = Plugin.filtering(:world_setting_list, Hash.new)
    metaworlds = world_dict.values
    case metaworlds.size
    when 0
      sequence.
        prompt(_('さて、このmikutterには……World Pluginが入ってないね。')).
        prompt(_('（こんなことする人が初めてなわけがないし……。もしかして、からかわれてる？）'))
      # TODO
    when 1
      sequence.
        prompt(_('さて、「mikutter」っていうのはご存知の通り、%{world_name}クライアントだよ。') % {world_name: metaworlds.first.name}).
        prompt(_('だからまずは%{world_name}アカウントを登録しようね。') % {world_name: metaworlds.first.name}).
        next { jump_seq(:wizard) }
    when 2
      sequence.
        prompt(_('このmikutterには%{world_name1}と%{world_name2}のプラグインが入ってるね。') % {world_name1: metaworlds[0].name, world_name2: metaworlds[1].name}).
        next { jump_seq(:wizard) }
    else
      sequence.
        prompt(_('このmikutterには%{world_name1}と%{world_name2}と…結構プラグイン入ってるね。') % {world_name1: metaworlds[0].name, world_name2: metaworlds[1].name}).
        next { jump_seq(:wizard) }
    end
  end

  defsequence :wizard do
    world_dict, = Plugin.filtering(:world_setting_list, Hash.new)
    UserConfig[:postbox_visibility] = :always
    UserConfig[:world_shifter_visibility] = :always
    sequence.
      say(_('左上にある「＋」みたいなマークをクリックして、「Worldを追加」を選んでね。'))
    world_wizard_open_observer = on_request_world_add do
      detach(world_wizard_open_observer)
      sequence.
        next{ Thread.new{ sleep 1 } }.
        say(
          world_dict.size == 1 ?
            _('%{world_name}アカウント追加ウィザードだよ。この画面はそのまま次に進んでね。') % {world_name: world_dict.values.first.name} :
            _('World追加ウィザードだよ。追加したいWorldを選んで、次に進んでね。')
        ).
        next{ Thread.new{ sleep 3 } }.
        say(_('そのあとは指示に従って認証情報とかを入れてね。私は見ないようにしておくから。')).next{
        world_created_observer = on_world_after_created do |world|
          detach(world_created_observer)
          jump_seq(:hello_world)
        end
      }.terminate("guide error")
    end
  end

  defsequence :hello_world do
    world = Plugin.collect(:worlds).first
    name =
      case
      when defined?(world.user.name)
        world.user.name
      when defined?(world.user_obj.name)
        world.user_obj.name
      end
    sequence.
      prompt(_('お疲れ様！登録できたよ。やっとmikutterを使えるね。')).
      prompt(_('私の出番はここまで。こんなふうに専用のタブであなたと会話するのはこれで最後。')).
      prompt(_('今後は、たまーにActivityにmikutterの便利な使い方を書いてあげるから、気づいたらやってみてね。')).
      prompt(name ?
               _('それじゃあ、またね。%{name}さん！') % {name: name} :
               _('それじゃあ、またね！')).
      next{ jump_seq :complete }
  end

  defsequence :skip do
    sequence.
      prompt(_('それじゃあ、またね。')).
      next{ jump_seq :complete }
  end

  defsequence :complete do
    Plugin.call(:finish_guide)
    sequence.
      prompt('（このタブは「閉じる」をクリックすると閉じることができます）',
          _('閉じる') => nil).
      next{
      tab(:guide).destroy
    }
  end

  defachievement(:tutorial,
                 description: _("mikutterのチュートリアルを見た"),
                 hint: _('← こんなアイコンのタブが右にあると思うので、クリックしてください'),
                 icon: Skin[:icon]
                ) do |ach|
    if Plugin.collect(:worlds).take(1).to_a.empty?
      guide_start(ach)
    else
      ach.take!
    end
  end
end

