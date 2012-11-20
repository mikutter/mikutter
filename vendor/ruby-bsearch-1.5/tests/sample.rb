#
# sample - Pick random N lines from a file.
#

num = 10
if ARGV[0] != nil && ARGV[0] =~ /^-(\d+)/ then
  num = $1.to_i
  ARGV.shift;
end

selected = []
lineno = 1
while line = gets
  rand = rand lineno
  if rand < num then
    selected.push line
    if selected.length > num then
      selected.delete_at rand
    end
  end
  lineno += 1
end

selected.each do |x|
  puts x
end
