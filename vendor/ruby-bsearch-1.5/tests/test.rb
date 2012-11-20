#
# Just for testing.
#

require 'bsearch'

def prefix_imatch (key, pattern)
  len = pattern.length
  raise if key == nil
  raise if pattern == nil
  key[0, len].downcase <=> pattern[0, len].downcase
end

def lookup (dict, pattern)
  first = dict.bsearch_first {|x| prefix_imatch x, pattern }
  last  = dict.bsearch_last  {|x| prefix_imatch x, pattern }
  range = dict.bsearch_range {|x| prefix_imatch x, pattern }

  if first != nil then
    raise "#{range.first} != #{first}" unless range.first == first
    raise "#{range.last}  != #{last}"  unless range.last == last + 1
    raise unless range == dict.bsearch_range(range) {|x| 
      prefix_imatch x, pattern }
    raise unless range == dict.bsearch_range(first..last) {|x| 
      prefix_imatch x, pattern }
    raise unless range == dict.bsearch_range(first...last + 1) {|x| 
      prefix_imatch x, pattern }

    range.each {|i|
      print i + 1, ":", dict[i], "\n"
    }
  end
end


def check_boundaries (dict)
  return if dict.empty?
  l = 0
  u = dict.length - 1
  raise unless (l...(l+1)) == dict.bsearch_range(l..l) {|x| x <=> dict.first}
  raise unless (u...(u+1)) == dict.bsearch_range(u..u) {|x| x <=> dict.last}
  raise unless (l...l) ==  dict.bsearch_range(l...l) {|x| x <=> dict.last}
  raise unless (u...u) ==  dict.bsearch_range(u...u) {|x| x <=> dict.last}
end


pattern = ARGV.shift
dict = Array.new
while line = gets
  line.chomp!
  dict.push line
end

check_boundaries(dict)
lookup(dict, pattern)
  
