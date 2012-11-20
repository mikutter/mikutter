#! /bin/sh

RUBYLIB="../"
export RUBYLIB

testcmd="ruby test.rb"

# 1000-dict:  usual dictionary with 1000 entries.
# 1-dict:     dictionary containing only one entry.
# 0-dict: empty dictionary.

for dict in 1000-dict 2-dict 1-dict 0-dict; do
    # prefix search.
    for pat in "" "a" "be" "st" "ta" "x" "Nonexistent"; do
	$testcmd "$pat"  $dict > tmp.dict.test
	egrep -in "^$pat" $dict > tmp.dict.egrep
	cmp tmp.dict.test tmp.dict.egrep || exit 1
    done

    # prefix search. iterate 50 times.
    for pat in `ruby sample.rb -50 $dict`; do
	$testcmd  "$pat"    $dict > tmp.dict.test
	egrep -in "^$pat" $dict > tmp.dict.egrep
	cmp tmp.dict.test tmp.dict.egrep || exit 1
    done

    # prefix search. for boundary entries.
    first=`head -1 $dict`
    last=`tail -1 $dict`
    for pat in $first $last; do
	$testcmd  "$pat"    $dict > tmp.dict.test
	egrep -in "^$pat" $dict > tmp.dict.egrep
	cmp tmp.dict.test tmp.dict.egrep || exit 1
    done
done

exit 0
