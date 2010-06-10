miquire :core, 'utils'

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
    notice "run #{@routine.inspect}(" + @args.map{|a| a.inspect}.join(', ') + ')'
    now = caller.size
    begin
      @routine.call(*@args)
    rescue Exception => e
      $@ = e.backtrace[0, now] + @backtrace
      raise e
    end
    notice "end. #{@routine.inspect}"
    @routine = nil
  end

  def self.run
    5.times{ |cnt|
      procs = []
      if not @@routines[cnt].empty? then
        atomic{
          procs = @@routines[cnt]
          @@routines[cnt] = Array.new }
        procs.each{ |routine| routine.run } end } end

  private
  def regist(prio)
    atomic{
      @@routines[prio] << self
    }
  end

end

