#########################
#       Utilities       #
#########################

require 'yaml'
require 'thread'
require 'resolv-replace'
require 'pstore'
require 'monitor'

#
# グローバル変数

$atomic = Monitor.new
$debug_avail_level = 2
HYDE = 156
MIKU = 39

#
# 制御構文
#

def miquire(kind, file=nil)
  path = ''
  case(kind)
  when :mui
    path = 'mui/gtk_'
  when :core
    path = ''
  when :user_plugin
    path = '../plugin/'
  else
    path = '' + kind.to_s + '/'
  end
  if file then
    if kind == :lib
      Dir.chdir(path){
        require file.to_s }
    else
      require path + file.to_s end
  else
    Dir.glob(path + "*.rb"){ |rb|
      require rb } end end

Dir::chdir(File::dirname(__FILE__))
miquire :lib, 'escape'

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

# num番目の引数をそのまま返す関数を返す
def ret_nth(num=0)
  lambda { |*arg| arg[num] }
end

# ファイルの内容を文字列に読み込む
def file_get_contents(fn)
  File.open(fn, 'r'){ |input|
    input.read
  }
end

# 文字列をファイルに書き込む
def file_put_contents(fn, body)
  File.open(fn, 'w'){ |put|
    put.write body
    return body
  }
end

# ファイルの内容からオブジェクトを読み込む
def object_get_contents(fn)
  File.open(fn, 'r'){ |input|
    Marshal.load input
  }
end

# オブジェクトをファイルに書き込む
def object_put_contents(fn, body)
  File.open(fn, 'w'){ |put|
    Marshal.dump body, put
  }
end

def confload(file)
  if(!file.is_a?(IO) && FileTest.exist?(File.expand_path(file))) then
    file = File.open(File.expand_path(file))
  else
    return Hash.new
  end
  YAML.load(file.read)
end

def pid_exist?(pid)
  if FileTest.exist? '/proc' then
    FileTest.exist? "/proc/#{pid}"
  else
    begin
      Process.kill(0, pid.to_i)
    rescue Errno::ESRCH
      return false
    else
      return true
    end
  end
end

def command_exist?(cmd)
  system("which #{cmd} > /dev/null")
end

def require_if_exist(file)
  begin
    require file
  rescue LoadError
    notice "require-if-exist: file not found: #{file}"
    nil
  end
end

def where_should_insert_it(insertion, src, order)
  if(order.include?(insertion)) then
    return src.dup.push(insertion).sort_by{|a|
      order.index(a) or 65536
    }.index(insertion)
  else
    return src.size
  end
end

# 一般メッセージを表示する
def notice(msg)
  log "notice", msg if $debug_avail_level >= 3
end

# 警告メッセージを表示する
def warn(msg)
  log "warning", msg if $debug_avail_level >= 2
end

# エラーメッセージを表示する
def error(msg)
  log "error", msg if $debug_avail_level >= 1
end

def assert_type(type, obj)
  if $debug and not obj.is_a?(type) then
    raise RuntimeError, "#{obj} should be type #{type}"
  end
  obj
end

def assert_hasmethods(obj, *methods)
  if $debug then
    methods.all?{ |m|
      raise RuntimeError, "#{obj.inspect} should have method #{m}" if not obj.methods.include? m
    }
  end
  obj
end

def log(prefix, msg)
  msg = "#{prefix}: #{caller(2).first}: #{msg}"
  if logfile() then
    FileUtils.mkdir_p(File.expand_path(File.dirname(logfile + '_')))
    File.open(File.expand_path("#{logfile}#{Time.now.strftime('%Y-%m-%d')}.log"), 'a'){ |wp|
      wp.write("#{Time.now.to_s}: #{msg}\n")
    }
  end
  if not $daemon then
    puts msg
  end
end

# エラーレベルを設定
def seterrorlevel(lv = :error)
  case(lv)
  when :notice
    $debug_avail_level = 3
  when :warn
    $debug_avail_level = 2
  when :error
    $debug_avail_level = 1
  else
    $debug_avail_level = lv
  end
end

#ログファイルを取得設定
def logfile(fn = nil)
  if(fn) then
    $logfile = fn
  end
  $logfile or nil
end

def atomic
  $atomic.synchronize(&Proc.new)
end

#Memoize
def memoize
  memo = Hash.new
  lambda{ |*args|
    if(memo.include?(args)) then
      memo[args]
    else
      memo[args] = yield(*args)
    end
  }
end

#Entity encode
def entity_unescape(str)
  str.gsub(/&(.{2,3});/){|s| {'gt'=>'>', 'lt'=>'<', 'amp'=>'&'}[$1] }
end

def bg_system(*args)
  cmd = args.map{|token| Escape.shell_command(token).to_s }.join(' ') + ' &'
  system('sh', '-c', cmd)
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

#
# Array
#
class Array
  #
  # ソース:http://d.hatena.ne.jp/sesejun/20070502/p1
  # ライセンス: GPL2
  #

  # 内部関数。[合計,長さ]
  def sum_with_number
    s = 0.0
    n = 0
    self.each do |v|
      next if v.nil?
      s += v.to_f
      n += 1
    end
    [s, n]
  end

  # 合計を返す
  def sum
    s, n = self.sum_with_number
    s
  end

  # 平均を返す
  def avg
    s, n = self.sum_with_number
    s / n
  end
  alias mean avg

  # 分散を返す
  def var
    c = 0
    while self[c].nil?
      c += 1
    end
    mean = self[c].to_f
    sum = 0.0
    n = 1
    (c+1).upto(self.size-1) do |i|
      next if self[i].nil?
      sweep = n.to_f / (n + 1.0)
      delta = self[i].to_f - mean
      sum += delta * delta * sweep
      mean += delta / (n + 1.0)
      n += 1
    end
    sum / n.to_f
  end

  # 標準偏差を返す
  def stddev
    Math.sqrt(self.var)
  end

  # (a[0],b[0]),(a[1],b[1]),... の相関係数を返す
  def corrcoef(y)
    raise "Invalid Argument Array Size" unless self.size == y.size
    sum_sq_x = 0.0
    sum_sq_y = 0.0
    sum_coproduct = 0.0
    c = 0
    while self[c].nil? || y[c].nil?
      c += 1
    end
    mean_x = self[c].to_f
    mean_y = y[c].to_f
    n = 1
    (c+1).upto(self.size-1) do |i|
      next if self[i].nil? || y[i].nil?
      sweep = n.to_f / (n + 1.0)
      delta_x = self[i].to_f - mean_x
      delta_y = y[i].to_f - mean_y
      sum_sq_x += delta_x * delta_x * sweep
      sum_sq_y += delta_y * delta_y * sweep
      sum_coproduct += delta_x * delta_y * sweep
      mean_x += delta_x / (n + 1.0)
      mean_y += delta_y / (n + 1.0)
      n += 1
    end
    pop_sd_x = Math.sqrt(sum_sq_x / n.to_f)
    pop_sd_y = Math.sqrt(sum_sq_y / n.to_f)
    cov_x_y = sum_coproduct / n.to_f
    cov_x_y / (pop_sd_x * pop_sd_y)
  end

  #
  # 以下、オリジナル
  #

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

end

class Hash
  # キーの名前を変換する。
  def convert_key(rule)
    result = {}
    self.each_pair { |key, val|
      if rule[key]
        result[rule[key]] = val
      else
        result[key.to_sym] = val
      end
    }
    result
  end
end

#
# String
#

class String
  def strsize
    self.split(//u).size
  end

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
    IO.popen('mecab -Owakati', 'r+'){ |io|
      io.write(self);
      io.close_write
      io.read
    }
  end

  def matches(regexp)
    result = []
    each_matches(regexp){ |m, pos|
      result << m }
    result
  end

  def each_matches(regexp)
    pos = 0
    str = self
    while(match = regexp.match(str))
      yield(match.to_s, pos + match.begin(0))
      str = match.post_match
      pos += match.end(0)
    end
  end

  def inspect
    to_s
  end

end

module GC
  @@lock_count = 0
  @@lock_mutex = Mutex.new

  def self.synchronize
    lock
    result = yield
    unlock
    result
  end

  def self.lock
    return
    @@lock_mutex.synchronize{
      if(@@lock_count == 0) then
        disable
      end
      @@lock_count += 1
    }
  end

  def self.unlock
    return
    @@lock_mutex.synchronize{
      @@lock_count -= 1
      if(@@lock_count == 0) then
        enable
      elsif(@@lock_count < 0) then
        error 'GC too many unlocked'
        abort
      end
    }
  end

end

class HatsuneStore < PStore
  def transaction(ro = false, &block)
    atomic{
      super(ro){ |db| block.call(db) }
    }
  end
end
