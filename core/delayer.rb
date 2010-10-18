require File.expand_path('utils')

class Delayer
  CRITICAL = 0
  FASTER = 1
  NORMAL = 2
  LATER = 3
  LAST = 4

  @@routines = [[],[],[],[],[]]

  def initialize(prio = NORMAL, *args, &block)
    @routine = block
    @args = args
    @backtrace = caller
    regist(prio)
  end

  def run
    #notice "run #{@routine.inspect}(" + @args.map{|a| a.inspect}.join(', ') + ')'
    now = caller.size
    begin
      @routine.call(*@args)
    rescue Exception => e
      $@ = e.backtrace[0, now] + @backtrace
      raise e
    end
    #notice "end. #{@routine.inspect}"
    @routine = nil
  end

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

