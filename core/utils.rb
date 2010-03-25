#########################
#       Utilities       #
#########################

require 'yaml'
require 'thread'
require 'resolv-replace'

#
# グローバル変数
#
$debug_avail_level = 2
HYDE = 156
MIKU = 39

#
# 制御構文
#

# 複数条件if
# 条件を二つ持ち、a&b,a&!b,!a&b,!a&!bの４パターンに分岐する
# procs配列は前から順番に、上記の条件の順番に対応している。
# 評価されたブロックの戻り値を返す。ブロックがない場合はfalseを返す。
# なお、ブロックはa,bを引数に取り呼び出される。
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
def ret_nth(num)
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

def miquire(kind, file=nil)
  path = ''
  case(kind)
  when :mui
    path = 'core/plugin/gtk_'
  when :core
    path = 'core/'
  else
    path = 'core/' + kind.to_s + '/'
  end
  if file then
    require path + file.to_s
  else
    Dir.glob(path + "*.rb") do |rb|
      require rb
    end
  end
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
    return src.push(insertion).sort{|a, b|
      if not(order.include?(a)) then 1
      elsif not(order.include?(b)) then -1
      else order.index(a) - order.index(b)
      end
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
    IO.popen('mecab -Owakati', 'r+'){ |io|
      io.write(self);
      io.close_write
      io.read
    }
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
