#
# 遅延評価
#
class Lazy
  def initialize
    @proc = Proc.new
    @obj = nil end

  def self.define_bridge(method, *remain)
    define_method(method){ |*args, &proc|
      method_missing(method, *args, &proc) }
    define_bridge(*remain) if not remain.empty?
  end

  define_bridge(*Object.methods)

  def method_missing(method, *args, &block)
    if @proc
      @obj = @proc.call
      @proc = nil end
    @obj.__send__(method, *args, &block) end end

def lazy(&proc)
  Lazy.new(&proc) end
