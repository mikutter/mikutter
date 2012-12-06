=begin
= Ruby/Bsearch: a binary search library for Ruby

Ruby/Bsearch is a binary search library for Ruby. It can search the FIRST or
LAST occurrence in an array with a condition given by a block.

Tha latest version of Ruby/Bsearch is available at 
((<URL:http://namazu.org/~satoru/ruby-bsearch/>))
.

== Example

  % irb -r ./bsearch.rb
  >> %w(a b c c c d e f).bsearch_first {|x| x <=> "c"}
  => 2
  >> %w(a b c c c d e f).bsearch_last {|x| x <=> "c"}
  => 5
  >> %w(a b c e f).bsearch_first {|x| x <=> "c"}
  => 2
  >> %w(a b e f).bsearch_first {|x| x <=> "c"}
  => nil
  >> %w(a b e f).bsearch_last {|x| x <=> "c"}
  => nil
  >> %w(a b e f).bsearch_lower_boundary {|x| x <=> "c"}
  => 2
  >> %w(a b e f).bsearch_upper_boundary {|x| x <=> "c"}
  => 2
  >> %w(a b c c c d e f).bsearch_range {|x| x <=> "c"}
  => 2...5
  >> %w(a b c d e f).bsearch_range {|x| x <=> "c"}
  => 2...3
  >> %w(a b d e f).bsearch_range {|x| x <=> "c"}
  => 2...2

== Illustration

<<< figure

== API

--- Array#bsearch_first (range = 0 ... self.length) {|x| ...}
    Return the index of the FIRST occurrence in an array with a condition given
    by block. Return nil if not found. Optional parameter `range' specifies the
    range of searching.
    To search an ascending order array,  let the block be like {|x| x <=> key}.
    To search an descending order array, let the block be like {|x| key <=> x}.
    Naturally, the array should be sorted in advance of searching. 

--- Array#bsearch_last (range = 0 ... self.length) {|x| ...}
    Return the index of the LAST occurrence in an
    array with a condition given by block. Return nil if not
    fount. Optional parameter `range' specifies the range of searching.
    To search an ascending order array,  let the block be like {|x| x <=> key}.
    To search an descending order array, let the block be like {|x| key <=> x}.
    Naturally, the array should be sorted in advance of searching. 

--- Array#bsearch_lower_boundary (range = 0 ... self.length) {|x| ...}
    Return the LOWER boundary in an array with a condition given
    by block. Optional parameter `range' specifies the
    range of searching.
    To search an ascending order array,  let the block be like {|x| x <=> key}.
    To search an descending order array, let the block be like {|x| key <=> x}.
    Naturally, the array should be sorted in advance of searching. 

--- Array#bsearch_upper_boundary (range = 0 ... self.length) {|x| ...}
    Return the UPPER boundary in an array with a condition
    given by block. Optional parameter `range' specifies the
    range of searching.
    To search an ascending order array,  let the block be like {|x| x <=> key}.
    To search an descending order array, let the block be like {|x| key <=> x}.
    Naturally, the array should be sorted in advance of searching. 

--- Array#bsearch_range (range = 0 ... self.length) {|x| ...}
    Return both the LOWER and the UPPER boundaries in an array with a condition
    given by block as Range object. Optional parameter
    `range' specifies the range of searching.
    To search an ascending order array,  let the block be like {|x| x <=> key}.
    To search an descending order array, let the block be like {|x| key <=> x}.
    Naturally, the array should be sorted in advance of searching. 

--- Array#bsearch (range = 0 ... self.length) {|x| ...}
    This is an alias to Array#bsearch_first.

== Download

Ruby/Bsearch is a free software with ABSOLUTELY NO WARRANTY
under the terms of Ruby's licence.

  * ((<URL:http://namazu.org/~satoru/ruby-bsearch/ruby-bsearch-1.4.tar.gz>))
  * ((<URL:http://cvs.namazu.org/ruby-bsearch/>))

satoru@namazu.org
=end
