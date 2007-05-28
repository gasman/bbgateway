#!/usr/local/bin/ruby

require 'nntp_server'
require 'activerecord_newsgroup_source'

port = ARGV.shift || 119
host = ARGV.shift # default is to bind everything

s = NNTPServer.new(:port => port, :host => host, :source => NewsgroupSource.new)

s.start