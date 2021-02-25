# frozen_string_literal: true
#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of FlightDesktopRestAPI.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# FlightDesktopRestAPI is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with FlightDesktopRestAPI. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on FlightDesktopRestAPI, please visit:
# https://github.com/openflighthpc/flight-desktop-restapi
#===============================================================================

ENV['RACK_ENV'] ||= 'development'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'rubygems'
require 'bundler'
require 'json'

if ENV['RACK_ENV'] == 'development'
  Bundler.require(:default, :development)
elsif ENV['RACK_ENV'] == 'test'
  Bundler.require(:default, :test)
else
  Bundler.require(:default)
end

lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'flight_desktop_restapi'
require_relative 'initializers/logger'

# Ensures the shared secret exists
FlightDesktopRestAPI.config.auth_decoder

require_relative '../app/system_command'
require_relative '../app/errors'
require_relative '../app/models'
require_relative 'initializers/version_check'
require_relative 'initializers/desktop_types'
require_relative '../app'

