#!/usr/local/bin/ruby

require 'nntp_server'

port = ARGV.shift || 119
host = ARGV.shift # default is to bind everything

s = NNTPServer.new(:port => port, :host => host)

s.start