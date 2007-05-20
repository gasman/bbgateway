#!/usr/bin/ruby -w

require 'nntp_server'
require 'dummy_nntp_server'

port = ARGV.shift || 119
host = ARGV.shift # default is to bind everything

s = DummyNNTPServer.new(:port => port, :host => host)

s.start