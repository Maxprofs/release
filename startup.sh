#!/bin/bash

bundle install
bundle exec rails server unicorn -c config/unicorn.rb -b 0.0.0.0 -p 3036
