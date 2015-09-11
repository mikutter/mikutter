# -*- coding: utf-8 -*-
# specファイル自動生成

require "fileutils"
require 'ripper'
miquire :core, "userconfig"

# イカサマ依存関係自動解決クラス。
# あまり頼りにしないでくれ、Rubyのパース面倒なんだよ
class Depend < Ripper::Filter
  attr_reader :spec
  def initialize(*args)
    @last_const = ""
    super end

  def set_spec(spec)
    @spec = spec
    self end

  # シンボル開始の:。次のidentをシンボルと見る
  def on_symbeg(tok, f)
    :symbol end

  def on_ident(tok, f)
    if f == :symbol
      on_ex_symbol(tok)
    else
      on_ex_ident(tok) end end

  # 定数。Gtk::TimeLine みたいなのが出てきた場合、on_const Gtk, on_op ::, on_const NestedQuote
  # の順番でイベントが発生するみたい…。
  def on_const(tok, f)
    if f == :op
      @last_const += '::' + tok
    else
      @last_const = tok end
    case @last_const
    when /\AG[td]k\Z/             # GtkクラスとかGdkクラス使ってたらgtkプラグインに依存してるだろう
      depend :gtk
    when /\APlugin::(\w+)/       # Plugin::なんとか は、プラグインスラッグのキャメルケース名なので、使ってたら依存してる
      depend $1.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym end end

  def on_op(tok, f)
    case tok
    when "::"
      :op end end

  # シンボル
  def on_ex_symbol(tok)
  end

  # 変数とかメソッド的なやつ。
  # command DSLを検出してもcommandプラグインには依存させない。
  # commandプラグインは基本的なmikutterコマンドを定義するだけで、mikutterコマンドの仕組み自体には関係ないから。
  # commandプラグインで使われている条件クラスを使っていたら、on_constで依存してると判断される。
  def on_ex_ident(tok)
    case tok
    when 'defactivity'
      depend :activity
    when 'tab', 'timeline', 'nativewidget' # UIっぽい単語があったらguiに依存してそう
      depend :gui
    when 'profiletab'         # profiletabはプロフィールにも依存する
      depend :gui
      depend :profile
    when 'settings'            # 設定DSLの開始。settingsプラグイン。
      depend :settings
    end end

  # slug に依存していることを登録する
  # ==== Args
  # [slug] 依存しているプラグイン (Symbol)
  def depend(slug)
    if spec['slug'].to_sym != slug and not spec["depends"]["plugin"].include?(slug.to_s)
      spec["depends"]["plugin"] << slug.to_s end end
end

def spec_generate(dir)
  specfile = File.join(dir, ".mikutter.yml")
  legacy_specfile = File.join(dir, "spec")
  spec = if FileTest.exist?(specfile)
           YAML.load_file(specfile)
         elsif FileTest.exist?(legacy_specfile)
           YAML.load_file(legacy_specfile)
         else
           user = UserConfig[:verify_credentials] || {}
           idname = user[:idname]
           {"slug" => File.basename(dir).to_sym, "depends" => {"mikutter" => Environment::VERSION.to_s}, "version" => "1.0", "author" => idname} end
  slug = spec["slug"].to_sym
  basefile = File.join(dir, "#{slug}.rb")
  unless FileTest.exist? basefile
    puts "file #{basefile} notfound. select plugin slug."
    expects = Dir.glob(File.join(dir, "*.rb")).map{ |filename| File.basename(filename, '.rb') }
    if expects.empty?
      puts "please create #{basefile}."
    end
    expects.each_with_index{ |filename, index|
      puts "[#{index}] #{filename}"
    }
    print "input number or slug [q:quit, s:skip]> "
    number = STDIN.gets.chomp
    case number
    when /q/i
      abort
    when /s/i
      return
    when /\A[0-9]+\Z/
      slug = expects[number.to_i].to_sym
    else
      slug = number.to_sym end
    spec["slug"] = slug
    basefile = File.join(dir, "#{slug}.rb") end
  source = File.open(basefile){ |io| io.read }

  if not spec.has_key?("name")
    print "#{slug}: name> "
    spec["name"] = STDIN.gets.chomp end
  if not spec.has_key?("description")
    print "#{slug}: description> "
    spec["description"] = STDIN.gets.chomp end
  spec["depends"] = {"version" => "1.0", "plugin" => []} if not spec.has_key?("depends")
  spec["depends"]["plugin"] = [] if not spec["depends"].has_key?("plugin")
  depend = Depend.new(source).set_spec(spec)
  depend.parse
  content = YAML.dump(depend.spec)
  File.open(specfile, "w"){ |io| io.write content }
  puts content
end

target = ARGV[1]
if target == "all"
  unless ARGV[2]
    puts "directory is not specified."
    puts "usage: mikutter.rb spec all directory"
    exit end
  Dir.glob(File.join(ARGV[2], "*/")).each{ |dir|
    spec_generate(dir) }
else
  unless ARGV[1]
    puts "directory is not specified."
    puts "usage: mikutter.rb spec directory"
    exit end
  spec_generate(target)
end
