# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of FlightDesktopServer.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# FlightDesktopServer is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with FlightDesktopServer. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on FlightDesktopServer, please visit:
# https://github.com/openflighthpc/flight-desktop-restapi
#===============================================================================

task :require_bundler do
  $: << __dir__
  $: << File.join(__dir__, 'lib')
  ENV['BUNDLE_GEMFILE'] ||= File.join(__dir__, 'Gemfile')

  require 'rubygems'
  require 'bundler'

  raise <<~ERROR.chomp unless ENV['RACK_ENV']
    Can not require the application because the RACK_ENV has not been set.
    Please export the env to your environment and try again:

    export RACK_ENV=production
  ERROR

  Bundler.require(:default, ENV['RACK_ENV'].to_sym)
end

task require: :require_bundler do
  require 'json'
  require 'sinatra'
  require 'config/initializers/figaro'
  require 'config/initializers/logger'
  require 'app/system_command'
  require 'app/errors'
  require 'app/models'
  require 'config/initializers/version_check'
  require 'config/initializers/desktop_types'
  require 'app'
end

task console: :require do
  Bundler.require(:default, ENV['RACK_ENV'].to_sym, :pry)
  binding.pry
end

# task 'token:admin', [:days] => :require do |task, args|
#   raise NotImplementedError
#   token = Token.new(admin: true)
#                .tap { |t| t.exp_days = args[:days].to_i if args[:days] }
#   puts token.generate_jwt
# end

# task 'token:user', [:days] => :require do |task, args|
#   token = Token.new.tap { |t| t.exp_days = args[:days].to_i if args[:days] }
#   puts token.generate_jwt
# end

