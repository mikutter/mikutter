# -*- coding: utf-8 -*-
# 多くの人に最初に突っ込まれるメソッドを定義するのだ

# ミクってかわいいよねぇ。
# ツインテールいいよねー。
# どう言いのかを書くとコードより長くなりそうだから詳しくは書かないけどいいよねぇ。
# ふたりで寒い時とかに歩いてたら首にまいてくれるんだよー。
# 我ながらなんてわかりやすい説明なんだろう。
# (訳: Miquire::miquire のエイリアス)
def miquire(*args)
  Miquire.miquire(*args)
end

module Miquire
  class << self

    PATH_KIND_CONVERTER = Hash.new{ |h, k| h[k] = k.to_s + '/' }
    # PATH_KIND_CONVERTER[:mui] = 'mui/gtk_'
    PATH_KIND_CONVERTER[:mui] = Class.new{
      define_method(:+){ |other|
        render = lambda{ |r| File.join('mui', "#{r}_" + other) }
        if other == '*' or FileTest.exist?(render[:cairo] + '.rb')
          render[:cairo]
        else
          render[:gtk] end } }.new
    PATH_KIND_CONVERTER[:core] = ''
    PATH_KIND_CONVERTER[:user_plugin] = '../plugin/'

    # CHIのコアソースコードファイルを読み込む。
    # _kind_ はファイルの種類、 _file_ はファイル名（拡張子を除く）。
    # _file_ を省略すると、そのディレクトリ下のrubyファイルを全て読み込む。
    # その際、そのディレクトリ下にディレクトリがあれば、そのディレクトリ内に
    # そのディレクトリと同じ名前のRubyファイルがあると仮定して読み込もうとする。
    # == Example
    #  miquire :plugin
    # == Directory hierarchy
    #  plugins/
    #  + a.rb
    #  `- b/
    #     + README
    #     + b.rb
    #     ` c.rb
    #  a.rbとb.rbが読み込まれる(c.rbやREADMEは読み込まれない)
    def miquire(kind, file=nil)
      kind = kind.to_sym
      if file
        if kind == :lib
          Dir.chdir(PATH_KIND_CONVERTER[kind]){
            miquire_original_require file.to_s }
        else
          file_or_directory_require PATH_KIND_CONVERTER[kind] + file.to_s end
      else
        miquire_all_files(kind) end end

    def plugin_loadpath
      @@plugin_loadpath ||= []
    end

    # miquireと同じだが、全てのファイルが対象になる
    def miquire_all_files(kind)
      kind = kind.to_sym
      Dir.glob(PATH_KIND_CONVERTER[kind] + '*').select{ |x| FileTest.directory?(x) or /\.rb$/ === x }.sort.each{ |rb|
        file_or_directory_require(rb) } end

    def file_or_directory_require(rb)
      if(match = rb.match(/^(.*)\.rb$/))
        rb = match[1] end
      case
      when FileTest.directory?(File.join(rb))
        plugin = (File.join(rb, File.basename(rb)))
        if FileTest.exist? plugin or FileTest.exist? "#{plugin}.rb"
          miquire_original_require plugin end
      else
        miquire_original_require rb end end

    def miquire_original_require(file)
      require file end

  end
end
