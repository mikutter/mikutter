miquire :core, 'utils'
=begin rdoc
= Delayer あとで処理を実行する
Delayer.new{ 処理 } のように使い、その処理を時間が開いたときに順次実行する。
メインルーチンが待ち時間に Delayer::run を呼び出さなければならない。
=end
class Delayer

  CRITICAL = 0
  FASTER = 1
  NORMAL = 2
  LATER = 3
  LAST = 4

  @@routines = [[],[],[],[],[]]

  # あとで実行する処理を登録する。
  # _prio_ には、 Delayer::CRITICAL , Delayer::Faster , Delayer::NORMAL , Delayer.LATER ,
  # Delayer.LAST のいずれかの優先順位を指定する。
  # 第二引数以降は、ブロックが実際に呼ばれるときに引数として渡される。
  def initialize(prio = NORMAL, *args, &block)
    @routine = block
    @args = args
    @backtrace = caller
    regist(prio)
  end

  # Delayer.new に渡されたブロックをすぐに実行する。
  def run
    now = caller.size
    begin
      @routine.call(*@args)
    rescue Exception => e
      p e
      $@ = e.backtrace[0, now] + @backtrace
      raise e
    end
    @routine = nil
  end

  # 予約されている処理を実行する。
  def self.run
    st = Process.times.utime
    5.times{ |cnt|
      procs = []
      if not @@routines[cnt].empty? then
        procs = @@routines[cnt].clone
        procs.each{ |routine|
          @@routines[cnt].delete(routine)
          routine.run
          return if (Process.times.utime - st) > 0.1 } end } end

  private
  def regist(prio)
    atomic{
      @@routines[prio] << self
    }
  end

end

