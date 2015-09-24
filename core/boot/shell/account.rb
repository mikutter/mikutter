# -*- coding: utf-8 -*-

miquire :boot, 'delayer'
miquire :lib, 'mikutwitter'
miquire :core, 'service', 'plugin'

puts "Register new account."

twitter = MikuTwitter.new
twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
request_token = twitter.request_oauth_token

puts "1) Access #{request_token.authorize_url}"
puts "2) Login twitter."
puts "3) Input PIN code."

print "PIN code>"
pin = STDIN.gets.chomp
processing = true
access_token = request_token.get_access_token(oauth_token: request_token.token,
                                              oauth_verifier: pin)
Service.add_service(access_token.token, access_token.secret).next{ |service|
  puts "Account @#{service.user_obj.idname} registered."
  processing = false
}.trap { |err|
  puts "Account register failed."
  puts err
  processing = false
  abort
}

while processing
  Delayer.run
  sleep 0.1
end
