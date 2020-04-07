#!/usr/bin/env ruby
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

begin
  # Extracts the user and command from the ruby ARGV
  user = ARGV.first
  argv = ARGV[1..-1]

  # Sets up the process with the user
  user_data = Etc.getpwnam(user)
  Process::Sys.setgid(user_data.gid)
  Process::Sys.setuid(user)
  Process.setsid

  # Sets up the environment for the user
  env = {
    'HOME' => user_data.dir,
    'USER' => user,
    'PATH' => ENV['PATH'],
    'TERM' => 'vt100'
  }

  # Executes the command
  exec(env, *argv, unsetenv_others: true)
rescue => e
  # Print any ruby errors to STDERR
  $stderr.puts e.message
ensure
  # This line should never be reached as the process should be replaced with exec
  exit 213
end

