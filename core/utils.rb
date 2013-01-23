# -*- coding: utf-8 -*-
=begin rdoc
CHI内部で共通で使われるユーティリティ。
=end

if defined? HYDE
  raise "HYDEが再定義されました。utils.rbを２回Linkしてるんじゃないか？それはいけない。すぐにバグをSHOT AT THE DEVILしろ。"
  # こんなふうにするといいと想います
  require File.expand_path(File.join(File.dirname(__FILE__), 'utils'))
end

require 'yaml'
require 'thread'
require 'resolv-replace'
require 'pstore'
require 'monitor'
require "open-uri"

$atomic = Monitor.new

# 基本的な単位であり、数学的にも重要なマジックナンバーで、至るところで使われる。
# これが言語仕様に含まれていないRubyは正直気が狂っていると思う。
# http://ja.uncyclopedia.info/wiki/Hyde
HYDE = 156

# Rubyのバージョンを配列で。あると便利。
RUBY_VERSION_ARRAY = RUBY_VERSION.split('.').map{ |i| i.to_i }.freeze

require File.join(File::dirname(__FILE__), 'miquire')

Dir::chdir(File::dirname(__FILE__))
['.', 'lib', 'miku'].each{|path|
  $LOAD_PATH.push(File.expand_path(File.join(Dir.pwd, path)))
}

miquire :lib, 'lazy'

# すべてのクラスにメモ化機能を
miquire :lib, 'memoize'
include Memoize

# Environment::CONFROOT内のファイル名を得る。
#   confroot(*path)
# は
#   File::expand_path(File.join(Environment::CONFROOT, *path))
# と等価。
def confroot(*path)
  File::expand_path(File.join(Environment::CONFROOT, *path))
end
miquire :core, 'environment'

# 複数条件if
# 条件を二つ持ち、a&b,a&!b,!a&b,!a&!bの４パターンに分岐する
# procs配列は前から順番に、上記の条件の順番に対応している。
# 評価されたブロックの戻り値を返す。ブロックがない場合はfalseを返す。
# なお、ブロックはa,bを引数に取り呼び出される。
# 誰得すぎて自分でも使ってないけどどこかで使った気がするなぁ
def biif(a, b, *procs, &last_proc)
  procs.push(last_proc)
  num = 0
  if not(a) then
    num += 2
  end
  if not(b) then
    num += 1
  end
  if(procs[num]) then
    procs[num].call(a,b)
  end
end

# _num_ 番目の引数をそのまま返す関数を返す
def ret_nth(num=0)
  lambda { |*arg| arg[num] } end

# スレッドセーフなカウンタを返す。
# カウンタの初期値は _count_ で、呼び出すたびに値が _increment_ づつ増える。
# なお、カウンタが返す値はインクリメント前の値。
def gen_counter(count=0, increment=1)
  mutex = Mutex.new
  lambda{
    mutex.synchronize{
      result = count
      count += increment
      result } } end

# ファイルの内容を文字列に読み込む
def file_get_contents(fn)
  open(fn, 'r:utf-8'){ |input|
    input.read
  }
end

# 文字列をファイルに書き込む
def file_put_contents(fn, body)
  File.open(fn, 'w'){ |put|
    put.write body
    body
  }
end

# ファイル _fn_ の内容からオブジェクトを読み込む。
# _fn_ は、object_put_contents() で保存されたファイルでなければならない。
def object_get_contents(fn)
  File.open(fn, 'r'){ |input|
    Marshal.load input
  }
end

# オブジェクト _body_ をファイル _fn_ に書き込む。
# _body_ は、Marshalizeできるものでなければならない。
def object_put_contents(fn, body)
  File.open(fn, 'w'){ |put|
    Marshal.dump body, put
  }
end

# YAMLファイルを読み込む。存在しない場合はからのハッシュを返す。
# _file_ は、IOオブジェクトかファイル名。
def confload(file)
  if(file.is_a?(IO))
    YAML.load(file.read)
  elsif(FileTest.exist?(File.expand_path(file))) then
    YAML.load(file_get_contents(file))
  else
    Hash.new
  end
end

# プロセスID _pid_ が存在するか否かを返す。
def pid_exist?(pid)
  if FileTest.exist? '/proc' then
    FileTest.exist? "/proc/#{pid}"
  else
    begin
      Process.kill(0, pid.to_i)
    rescue Errno::ESRCH
      false
    else
      true end end end

# UNIXコマンド _cmd_ が存在するか否かを返す。
def command_exist?(cmd)
  system("which #{cmd} > /dev/null")
end

# 存在するかわからないrubyファイル _file_ を読み込む。
# ただし、_file_ が存在しない場合は例外を投げずにfalseを返す。
def require_if_exist(file)
  begin
    require file
    true
  rescue LoadError
    notice "require-if-exist: file not found: #{file}"
    false end end

# _insertion_ を、 _src_ の挿入するべき場所のインデックスを返す。
# _order_ は順番を表す配列で、 _src_ 内のオブジェクトの前後関係を表す。
# _order_ 内に _insertion_ が存在しない場合は一番最後のインデックスを返す
def where_should_insert_it(insertion, src, order)
  if(order.include?(insertion)) then
    src.dup.push(insertion).sort_by{|a|
      order.index(a) or 65536
    }.index(insertion)
  else
    src.size end end

# 一般メッセージを表示する。
def notice(msg)
  log "notice", msg if Mopt.error_level >= 3
end

# 警告メッセージを表示する。
def warn(msg)
  log "warning", msg if Mopt.error_level >= 2
end

# エラーメッセージを表示する。
def error(msg)
  log "error", msg if Mopt.error_level >= 1
  abort if Mopt.error_level >= 4
end

# --debug オプション付きで起動されている場合、インタプリタに入る。
# ==== Args
# [exception] 原因となった例外
# [binding] インタプリタを実行するスコープ
# ==== Return
# インタプリタから復帰したら(インタプリタが起動されたら)true、
# デバッグモードではない、pryがインストールされていない等、起動に失敗したらfalse
def into_debug_mode(exception = nil, bind = binding)
  if Mopt.debug and not Mopt.testing
    require_if_exist 'pry'
    if binding.respond_to?(:pry)
      log "error", exception if exception
      $into_debug_mode_lock.synchronize {
        begin
          $into_debug_mode = Set.new
          bind.pry
        ensure
          threads = $into_debug_mode
          $into_debug_mode = false
          threads.each &:wakeup end }
      return true end end end
$into_debug_mode = false
$into_debug_mode_lock = Monitor.new

# 他のスレッドでinto_debug_modeが呼ばれているなら、それが終わるまでカレントスレッドをスリープさせる
def debugging_wait
  if $into_debug_mode
    $into_debug_mode << Thread.current
    Thread.stop end end

# 引数のチェックをすべてパスした場合のみブロックを実行する
# チェックに引っかかった項目があればwarnを出力してブロックは実行せずにnilを返す。
# チェックはassocできる配列か、Hashで定義する。
#  type_check(value => nil,              # チェックしない(常にパス)
#             value => Module,           # その型とis_a?関係ならパス
#             value => [:method, *args], # value.method(*args)が真を返せばパス
#             value => lambda{ |x| ...}) # xにvalueを渡して実行し、真を返せばパス
# チェックをすべてパスしたかどうかを真偽値で返す。
# ブロックが指定されていれば、それを実行してブロックの実行結果を返す
# メモ: いずれかのタイプに一致するチェックを定義するにはtcorを使う
#   type_check object => tcor(Array, Hash)
def type_check(args, &proc)
  check_function = lambda{ |val, check|
    if not check
      true
    elsif check.is_a? Array
      val.__send__(*check)
    elsif check.is_a? Symbol
      val.respond_to?(check)
    elsif check.is_a?(Class) or check.is_a?(Module)
      val.is_a?(check)
    elsif check.respond_to?(:call)
      check.call(val) end }
  error = args.find{ |a| not(check_function.call(*a)) }
  if(error)
    warn "argument error: #{error[0].inspect} is not passed #{error[1].inspect}"
    warn "in #{caller_util}"
    false
  else
    if proc
      proc.call
    else
      true end end end

# _types_ のうちいずれかとis_a?関係ならtrueを返すProcオブジェクトを返す
def tcor(*types)
  lambda{ |v| types.any?{ |c| v.is_a?(c) } } end

# type_checkと同じだが、チェックをパスしなかった場合にabortする
# type_checkの戻り値を返す
def type_strict(args, &proc)
  result = type_check(args, &proc)
  if not result
    into_debug_mode(binding)
    raise ArgumentError.new end
  result end

# blockの評価結果がチェックをパスしなかった場合にabortする
def result_strict(must, &block)
  result = block.call
  type_strict(result => must)
  result
end

# カレントスレッドがメインスレッドかどうかを返す
def mainthread?
  Thread.main == Thread.current end

# メインスレッド以外で呼び出されたらThreadErrorを投げる
def mainthread_only
  unless mainthread?
    raise ThreadError.new('The method can calls only main thread. but called by another thread.') end end

# メインスレッドで呼び出されたらThreadErrorを投げる
def no_mainthread
  if mainthread?
    raise ThreadError.new('The method can not calls main thread. but called by main thread.') end end

# type_checkで型をチェックしてからブロックを評価する無名関数を生成して返す
def tclambda(*args, &proc)
  lambda{ |*a|
    if proc.arity >= 0
      if proc.arity != a.size
        raise ArgumentError.new("wrong number of arguments (#{a.size} for #{proc.arity})") end
    elsif -(proc.arity+1) > a.size
      raise ArgumentError.new("wrong number of arguments (#{a.size} for #{proc.arity})") end
    proc.call(*a) if type_check(a.slice(0, args.size).zip(args)) } end

# utils.rbのメソッドを呼び出した最初のバックトレースを返す
def caller_util
  caller.each{ |result|
    return result unless /utils\.rb/ === result } end

def caller_util_all
  aflag = false
  result = []
  caller.each{ |c|
    aflag |= /utils\.rb/ === c
    result << c if aflag }
  result end


# デバッグモードの場合、_obj_ が _type_ とis_a?関係にない場合、RuntimeErrorを発生させる。
# _obj_ を返す。
def assert_type(type, obj)
  if Mopt.debug and not obj.is_a?(type)
    raise RuntimeError, "#{obj} should be type #{type}"
  end
  obj
end

# デバッグモードの場合、_obj_ _methods_ に指定されたメソッドをひとつでも持っていない場合、
# RuntimeErrorを発生させる。
# _obj_ を返す。
def assert_hasmethods(obj, *methods)
  if Mopt.debug
    methods.all?{ |m|
      raise RuntimeError, "#{obj.inspect} should have method #{m}" if not obj.methods.include? m
    }
  end
  obj
end

# エラーログに記録する。
# 内部処理用。外部からは呼び出さないこと。
def log(prefix, object)
  debugging_wait
  begin
    msg = "#{prefix}: #{caller_util}: #{object}"
    msg += "\nfrom " + object.backtrace.join("\nfrom ") if object.is_a? Exception
    unless $daemon
      if msg.is_a? Exception
        __write_stderr(msg.to_s)
        __write_stderr(msg.backtrace.join("\n"))
      else
        __write_stderr(msg) end
      if logfile
        FileUtils.mkdir_p(File.expand_path(File.dirname(logfile + '_')))
        File.open(File.expand_path("#{logfile}#{Time.now.strftime('%Y-%m-%d')}.log"), 'a'){ |wp|
          wp.write("#{Time.now.to_s}: #{msg}\n") } end end
  rescue Exception => e
    __write_stderr("critical!: #{caller(0)}: #{e.to_s}")
  end
end

FOLLOW_DIR = File.expand_path('..')
def __write_stderr (msg)
  $stderr.write(msg.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}')+"\n")
end

# 環境や設定の不備で終了する。msgには、何が原因かを文字列で渡す。このメソッドは
# 処理を返さずにアボートする。
def chi_fatal_alert(msg)
  require_if_exist 'gtk2'
  if defined?(Gtk::MessageDialog)
    dialog = Gtk::MessageDialog.new(nil,
                                    Gtk::Dialog::DESTROY_WITH_PARENT,
                                    Gtk::MessageDialog::ERROR,
                                    Gtk::MessageDialog::BUTTONS_CLOSE,
                                    "#{Environment::NAME} エラー")
    dialog.secondary_text = msg.to_s
    dialog.run
    dialog.destroy end
  puts msg.to_s
  abort end

#ログファイルを取得設定
def logfile(fn = nil)
  if(fn) then
    $logfile = fn
  end
  $logfile or nil
end

# 共通のMutexで処理を保護して実行する。
# atomicブロックで囲まれたコードは、別々のスレッドで同時に実行されない。
def atomic
  # if Thread.current == Thread.main
  #    raise 'Atomic Mutex dont have to block main thread'
  # end
  $atomic.synchronize{ yield }
end

# 文字列をエンティティデコードする
def entity_unescape(str)
  str.gsub(/&(.{2,3});/){|s| {'gt'=>'>', 'lt'=>'<', 'amp'=>'&'}[$1] }
end

# コマンドをバックグラウンドで起動することを覗いては system() と同じ
def bg_system(*args)
  Process.detach(spawn(*args))
end

def wakachigaki(str, ret_io=false)
  if(ret_io)
    IO.popen('mecab -Owakati', 'r+').tap{ |io|
      io.write(str)
      io.close_write }
  else
    IO.popen('mecab -Owakati', 'r+'){ |io|
      io.write(str)
      io.close_write
      io.read } end end

class Module
  # ハッシュ用のアクセサ。最初から空の連想配列が入っている
  # 引数なしで呼び出すとハッシュ自身を返し、１つ引数を与えると、引数をキーにハッシュの値を返す
  def attr_hash_accessor(*names)
    names.each { |name|
      hash = {}
      define_method(name){ |*args|
        case args.size
        when 0
          hash
        when 1
          hash[args[0]]
        when 2
          hash[args[0]] = args[1] end } } end end

class Object

  def self.defun(method_name, *args, &proc)
    define_method(method_name, &tclambda(*args, &proc)) end

  # freezeできるならtrueを返す
  def freezable?
    true end

  # freezeできる場合はfreezeする。selfを返す
  def freeze_ifn
    freeze if freezable?
    self end

  # freezeされていない同じ内容のオブジェクトを作って返す。
  # メルト　溶けてしまいそう　（実装が）dupだなんて　絶対に　言えない
  def melt
    if frozen? then dup else self end end end

#
# Numeric
#

class Numeric
  def freezable?
    false end end

#
# Integer
#

class Integer
  # ページあたりone_page_contain個の要素が入る場合に、self番目の要素は何ページ目に来るかを返す
  def page_of(one_page_contain)
    (self.to_f / one_page_contain).ceil end

end

#
# Float
#

class Float
  # 小数n桁以前を削除
  def floor_at(n)
    (self * 10**n).floor.to_f / 10**n
  end
  def ceil_at(n)
    (self * 10**n).ceil.to_f / 10**n
  end
  def round_at(n)
    (self * 10**n).round.to_f / 10**n
  end

  # 百分率を返す（小数n桁まで）
  def percent(n=0)
    (self*100).floor_at(n)
  end

end

module Enumerable

  # 複数のeachの代わりになるメソッドを同時に使って繰り返す。
  # 引数には、メソッド名をシンボルで渡すか、[メソッド名, 引数...]という配列を渡せる。
  # 例 :
  #   ary = [1, 2, 3]
  #   ary.iterate(:each_with_index, [:inject, [:foo]]){ |a, x| a + x } # => [:foo, 1, 0, 2, 1, 3, 2]
  def iterate(*methods)
    methods.inject(self){ |itr, method|
      method = [method] unless method.is_a? Array
      Enumerable::Enumerator.new(itr, *method) }.each(&Proc.new) end

  # 各要素の[0]がキー、[1]が値のHashを返す。
  # ブロックが渡された場合、mapしてからto_hashした結果を返す。
  def to_hash
    result = Hash.new
    if(block_given?)
      each{ |value|
        key, val, = yield(value)
        result[key] = val }
    else
      each{ |value|
        result[value[0]] = value[1] } end
    result end

end

#
# Array
#
class Array
  include Comparable

  # index番目からlength個の要素を先頭にもっていく
  def bubbleup!(index, length=1)
    if index.abs >= self.size
      return nil
    end
    self[0,0]= self.slice!(index, length)
    self
  end

  def bubbleup(index, length=1)
    self.clone.bubbleup!(index, length)
  end

  # index番目からlength個の要素を末尾にもっていく
  def bubbledown!(index, length=1)
    if index.abs >= self.size
      return nil
    end
    self[self.size-length..0]= self.slice!(index, length)
    self
  end

  def bubbledown(index, length=1)
    self.clone.bubbledown!(index, length)
  end

  # 1.9のrindexと同じ挙動
  def reverse_index(val=nil, &proc)
    if proc
      val = Class.new{
        define_method(:==, &proc) }.new end
    rindex(val) end

  # 1.9のindexと同じようにブロックを渡すことができる
  def index(val = nil) # !> method redefined; discarding old index
    compare = if(block_given?)
                Proc.new
              else
                lambda{ |x| x == val } end
    each_with_index{ |x, i|
      return i if compare[x] }
    nil end

  def symbolize
    result = []
    each { |val|
      result << if val.respond_to?(:symbolize) then val.symbolize else val end }
    result
  end

end

class Hash
  # キーの名前を変換する。
  def convert_key(rule = nil)
    if block_given?
      convert_key_proc(&Proc.new)
    else
      convert_key_hash(rule) end end

  def convert_key_proc(&rule)
    result = {}
    self.each_pair { |key, val|
      result[rule.call(key)] = val }
    result end

  def convert_key_hash(rule)
    result = {}
    self.each_pair { |key, val|
      if rule[key]
        result[rule[key]] = val
      else
        result[key.to_sym] = val end }
    result end

  # キーを全てto_symしたhashを新たにつくる
  def symbolize
    result = {}
    each_pair { |key, val|
      result[key.to_sym] = if val.respond_to?(:symbolize) then val.symbolize else val end }
    result
  end

  # 1.8でもHash#keyが正常に動作するようにする
  unless(Hash.new.respond_to?(:key))
    alias key index
  end

end

#
# String
#

class String

  # 最初に文字列内に見つかった小数を返す
  def trim_f()
    if /-{0,1}\d+\.\d+/ =~ self then
      return Regexp.last_match[0].to_f
    end
    return nil
  end

  # 最初に文字列内に見つかった整数を返す
  def trim_i()
    if /-{0,1}\d+/ =~ self then
      return Regexp.last_match[0].to_i
    end
    return nil
  end

  # 最初に文字列内に見つかった数を返す
  def trim_n()
    biif(self.trim_i, self.trim_f, ret_nth(1), ret_nth(0))
  end

  # 日本語の分かち書きをする
  def to_wakati()
    wakachigaki(self)
  end
  alias to_wakachi to_wakati

  # 日本語の分かち書きをする。mecabをスタートさせたら直ちにIOオブジェクトを返す。
  # 実際の結果文字列はIO#readで読む。
  def to_wakatio()
    wakachigaki(self, true)
  end
  alias to_wakachio to_wakatio

  # 引数にStringを渡したら、正規表現にコンパイルするmatch
  def match_regexp(str)
    if(str.is_a? String)
      match(Regexp.new(str))
    else
      match(str) end end

  def matches(regexp)
    result = []
    each_matches(regexp){ |m, pos|
      result << m.to_s }
    result
  end

  def each_matches(regexp, &proc) # :yield: match, byte_index, char_intex
    pos = 0
    str = self
    while(match = regexp.match(str))
      if(proc.arity == 1)
        proc.call(match)
      elsif(proc.arity == 2)
        proc.call(match, pos + match.begin(0))
      else
        proc.call(match, pos + match.begin(0), pos + match.begin(0)) end
      str = match.post_match
      pos += match.end(0) end end

  def shrink(count, uni_char=nil, separator=' ')
    o_match = uni_char && match(uni_char)
    if o_match
      pure_matched = o_match.pre_match + o_match[0]
      sh_post = lazy{ o_match.post_match.shrink([count - pure_matched.size, 0].max, uni_char, separator) }
      sh_head = lazy{ o_match.pre_match[0, [0, count-separator.size-o_match[0].size].max] }
      if pure_matched.size <= count
        pure_matched + sh_post
      elsif not sh_head.nil?
        (sh_head.empty? ? '' : sh_head + separator) + o_match[0] + sh_post
      else
        o_match[0].shrink(count, uni_char, separator)
      end
    elsif empty?
      ""
    else
      self[0,count] end end

  # _byte_ バイト目が何文字目にあたるかを返す
  def get_index_from_byte(byte)
    result = 0
    split(//u).each{ |c|
      byte -= c.to_enum(:each_byte).to_a.size
      return result if(byte < 0)
      result += 1 }
    result end

  def inspect
    '"'+to_s+'"'
  end

end

class Symbol
  def freezable?
    false end end

class TrueClass
  def freezable?
    false end end

class FalseClass
  def freezable?
    false end end

class NilClass
  def freezable?
    false end end

class Regexp
  def to_json(*a)
    {
      'json_class'   => self.class.name,
      'data'         => to_s
    }.to_json(*a)
  end

  def self.json_create(o)
    new(o['data'])
  end
end

class HatsuneStore < PStore

  def initialize(*args)
    extend MonitorMixin
    super
  end

  def transaction(ro = false, &block)
    start = Time.now
    result = synchronize{
      super(ro){ |db| block.call(db) } }
    if (Time.now - start) >= 0.1
      notice (Time.now - start).round_at(4).to_s
    end
    result
  end
end

def is_fib?(n)
  x = 1
  loop{
    if(fib(x) == n)
      return true
    elsif(fib(x) > n)
      return false end
    x += 1 } end

def fib(n)
  return n if n < 2
  fib(n-1) + fib(n-2)
end
memoize(:fib)
