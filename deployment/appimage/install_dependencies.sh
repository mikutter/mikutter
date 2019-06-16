#!/bin/bash
set -Ceu
shopt -s globstar

echo "--> install dependencies"
sudo apt update
sudo apt install -y git
sudo apt install -y libssl-dev libreadline6-dev libgdbm3 libgdbm-dev # for ruby
sudo apt install -y zlib1g-dev # for `gem install`
sudo apt install -y libidn11-dev # for idn-ruby
