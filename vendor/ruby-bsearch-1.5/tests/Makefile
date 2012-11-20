check: 0-dict 1-dict 2-dict 1000-dict
	@sh test.sh && echo ok

0-dict:
	touch 0-dict

1-dict:
	grep '^[a-zA-z]*$$' /usr/share/dict/words |\
	ruby sample.rb -1  > 1-dict

2-dict:
	grep '^[a-zA-z]*$$' /usr/share/dict/words |\
	ruby sample.rb -1  > 2-dict

1000-dict:
	grep '^[a-zA-z]*$$' /usr/share/dict/words |\
	ruby sample.rb -1000  > 1000-dict

clean:
	rm -f tmp.*
