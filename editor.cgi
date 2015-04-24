#!/usr/bin/ruby -EUTF-8
# -*- mode:Ruby; coding:utf-8 -*-
=begin
editor.cgi -- 2015-04-08, written by UNNO Hideyuki (unno.hideyuki@nifty.com).
=end

require 'cgi'
$: << File.dirname(__FILE__)
require 'lib/studs.rb'
require 'lib/studs_conf.rb'

cgi = CGI.new
conf = Conf.load("studs.conf")

begin
  cgi_main(cgi, conf)
rescue => e
  cgi.out("Content-Type" => "text/plain"){ 
    e.to_s + "\n\n" + e.backtrace.join("\n") 
  }
end
