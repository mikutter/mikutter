miquire :core, 'utils'

class Delayer
  CRITICAL = 0
  FASTER = 1
  NORMAL = 2
  LATER = 3
  LAST = 4

  @@routines = [[],[],[],[],[]]
  @@lock = Monitor.new

  def initialize(prio = NORMAL, *args, &block)
    @routine = block
    @args = args
    regist(prio)
  end

  def run
    notice "run #{@routine.inspect}(" + @args.map{|a| a.inspect}.join(', ') + ')'
    @routine.call(*@args)
    notice "end. #{@routine.inspect}"
    @routine = nil
  end

  def self.run
    @@lock.synchronize{
      catch(:ran){
        5.times{ |cnt|
          if not @@routines[cnt].empty? then
            @@routines[cnt].each{ |routine| routine.run }
            @@routines[cnt].clear
            # throw :ran
          end
        }
      }
    }
  end

  private
  def regist(prio)
    @@lock.synchronize{
      @@routines[prio] << self
    }
  end

end

