#
# Plugin
#

miquire :core, 'configloader'
miquire :core, 'environment'

require 'monitor'

module Plugin
  # プラグインのスーパクラス。
  # 主にイベントハンドラを実装する
  class Plugin
    include ConfigLoader

    # プラグインの名前を返す
    def name
      self.class.to_s.split(/::/).last.downcase
    end

    # oncallが呼ばれる条件。
    # これに一致するタグが指定されたときのみ、ハンドラが呼ばれる。
    def call_tag
      self.name
    end

    # コンフィグファイルを返す。
    def config
      if(@config) then
        return @config
      else
        @config = confload("#{Environment::CONFROOT}#{self.name}")
      end
    end

    # 指定されたイベントハンドラを、イベント発生毎に呼ぶのではなく
    # 全てをひとつの配列にまとめて呼び出すようにする
    def self.get_all_parameter_once(*names)
      names.each{ |name|
        # remove_method(name.to_sym)
        define_method(name.to_sym){ |args|
          self.__send__("on#{name.to_s}".to_sym, args)
        }
      }
    end

    # on + 自分の名前をそのまま呼び出すメソッドを定義するメソッド
    def self.normal_event_handler(*names)
      names.each{ |name|
        define_method(name.to_sym){ |args|
          args.each{ |arg|
            self.__send__("on#{name.to_s}".to_sym, *arg)
          }
        }
      }
    end
    private_class_method :normal_event_handler

    # 起動時に一度だけ呼ばれるイベントハンドラ。
    # 一度しか呼ばれないことが保証されており、どのイベントハンドラ
    # よりも先に呼ばれる。
    normal_event_handler :boot

    # 他のプラグインを呼ぶためのイベント。
    # commandはサブコマンド、messageにその引数を渡す。
    normal_event_handler :plugincall

    def onplugincall(*trash)
      p 'undefined event onplugincall called '+trash.inspect
      return nil
    end

    # 毎分呼ばれるイベントハンドラ。
    # ある条件にマッチする時だけpostするようなコードを書くことを推奨。
    # watchは、postメソッドを実装していて、もしpostしたいときはそれを
    # 呼び出す。
    # イベントによって何もしなかった場合はnil、何かした場合はtrue、
    normal_event_handler :period

    # ハッシュタグを受け取った時に呼ばれるイベントハンドラ。
    # postは、イベントを引き起こしたpost。
    # イベントによって何もしなかった場合はnil、何かした場合はtrue、
    normal_event_handler :call

    # リプライを受け取った時に呼ばれるイベントハンドラ。
    # postは、イベントを引き起こしたpost。
    # イベントによって何もしなかった場合はnil、何かした場合はtrue、
    normal_event_handler :mention

    # タイムラインが更新されたときに、１ポスト毎に呼ばれるイベント
    # ハンドラ。
    # postは、イベントを引き起こしたpost。
    # イベントによって何もしなかった場合はnil、何かした場合はtrue、
    # postを返した場合はwatch.postの戻り値を返す。
    normal_event_handler :update

    # 誰かにフォローされた時に呼び出されるイベントハンドラ。
    # userは、新たにフォローしてきたユーザ。
    # イベントによって何もしなかった場合はnil、何かした場合はtrue、
    # postを返した場合はwatch.postの戻り値を返す。
    normal_event_handler :followed

  end
end

miquire :plugin, 'mother'

module Plugin
  # プラグイン保存用の格納庫。
  # 各プラグインから以下のように使う。
  # Plugin::Ring.push Plugin::クラス名.new
  # こうすることで、定期的にperiodが呼ばれたりする
  module Ring
    @@ring = Hash.new{ [] }
    @@mother = Mother.new
    @@lock = Monitor.new
    @@plugins = Hash.new
    @@fire = Hash.new{ Array.new }

    # handlerにイベントハンドラvalを登録する。
    # イベントが起こったときには、シンボル名と同名のメソッドが呼ばれる。
    def self.push(val, handlers=[:period])
      unless handlers.is_a?(Array) then
        handlers = [handlers]
      end
      handlers.each{ |handler|
        @@ring[handler] = @@ring[handler].push(val)
      }
      @@plugins[val.name.to_sym] = val
    end

    # handler から特定のクラスを削除する
    def self.delete(handler, item)
      @@ring[handler].reject!{ |node|
        node.class == item.class
      }
    end

    # イベントを呼び出す
    # argsには、引数リストを要求する
    def self.fire(handler, args)
      @@lock.synchronize{
        Gtk::Lock.synchronize{
          @@mother.__send__(handler, [args])
        }
      }
    end

    # イベントを予約
    # 実際の呼び出しはgoが呼ばれたときに行われる
    # argsには、[[引数1], [引数2], ...[引数n]]を要求する
    def self.reserve(handler, arglist)
      @@lock.synchronize{
        @@fire[handler] = @@fire[handler].concat(arglist)
      }
    end

    # 予約されていたイベントを呼び出す
    def self.go
      @@lock.synchronize{
        Gtk::Lock.synchronize{
          @@fire.each{ |handler, event|
            @@mother.__send__(handler, event)
          }
        }
        @@fire = Hash.new{ Array.new }
      }
    end

    # 有効なプラグインを取得する
    def self.avail_plugins(handler=nil)
      if handler == :all then
        @@plugins
      elsif handler then
        @@ring[handler]
      else
        @@ring
      end
    end

    def self.[](handler)
      return self.avail_plugins(handler)
    end

  end

end

miquire :plugin
