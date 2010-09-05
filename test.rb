#! /usr/bin/ruby

Dir.glob(File.dirname(__FILE__) + '/core/test/test.*').each{ |f|
  unless system("ruby #{f}")
    puts "test failed #{f}"
    abort
  end
}

puts 'all test case passed'

# ~> warning: ./miku/miku.rb:26:in `miku_stream': MIKU::EndofFile
# ~> from ./parser.rb:125:in `_symbol'
# ~> from ./parser.rb:47:in `_parse'
# ~> from ./parser.rb:15:in `parse'
# ~> from ./miku/miku.rb:24:in `miku_stream'
# ~> from ./symboltable.rb:23:in `run_init_script'
# ~> from ./plugin/gui.rb:275
# ~> from ./utils.rb:42:in `require'
# ~> from ./utils.rb:42:in `miquire'
# ~> from ./utils.rb:41:in `each'
# ~> from ./utils.rb:41:in `miquire'
# ~> from ./plugin/plugin.rb:181
# ~> from ./utils.rb:39:in `require'
# ~> from ./utils.rb:39:in `miquire'
# ~> from ./core/test/test.user.rb:4
# ~> notice: ./core/test/test.utils.rb:16:in `test_shrink': 270
# >> Loaded suite ./core/test/test.message
# >> Started
# >> .
# >> Finished in 0.002595 seconds.
# >> 
# >> 1 tests, 9 assertions, 0 failures, 0 errors
# >> Loaded suite ./core/test/test.retriever
# >> Started
# >> .
# >> Finished in 0.000371 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
# >> Loaded suite ./core/test/test.user
# >> Started
# >> .
# >> Finished in 0.298027 seconds.
# >> 
# >> 1 tests, 2 assertions, 0 failures, 0 errors
# >> Loaded suite ./core/test/test.utils
# >> Started
# >> 10.10の開発は9月2日のBetaリリースを控え，UserInterfaceFreeze・BetaFreezeを無事に通過しました。以降は原則としてGUI部分の大きな変更はなく，各機能のブラッシュアップに入ります。Ubuntu Week http://bit.ly/123456
# >> .
# >> Finished in 0.001313 seconds.
# >> 
# >> 1 tests, 0 assertions, 0 failures, 0 errors
# >> all test case passed
