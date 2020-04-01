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
# https://github.com/openflighthpc/flight-desktop-server
#===============================================================================

# NOTE: The specs do not require the CLI
return if Figaro.env.RACK_ENV! == 'test'

require 'rubygems'

supported_version = File.read(File.expand_path('../../.cli-version', __dir__))
                        .chomp

raw_version = SystemCommand.version(user: Figaro.env.USER!)
                           .tap(&:raise_unless_successful)
                           .stdout
cli_version = /\d+\.\d+\.\d+/.match(raw_version)[0]

low = Gem::Version.new(supported_version)
high = Gem::Version.new(cli_version)

return if low <= high
raise <<~ERROR if high < low

  The server can not be started due to an incompatible version of 'flight desktop'
  Requires: #{supported_version}
  Current:  #{cli_version}
ERROR

