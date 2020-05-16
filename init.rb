require 'bundler/setup'
Bundler.require
require "sinatra/reloader"
require "./gmt-tools-config"
require "./gmt-tools-lib"
require "./notification"
require "./gmt-server"
require "./application_controller"
