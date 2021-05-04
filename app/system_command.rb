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

require 'erb'
require 'shellwords'
require 'open3'
require 'etc'

class SystemCommand < Hashie::Dash
  class Builder
    attr_reader :base_argv

    def initialize(cmd)
      @base_argv ||= cmd.split("\s")
    end

    # The bootstrapping script is responsible for setting up the user environment
    def call(*cmd_argv, user:)
      read_out, write_out = IO.pipe
      read_err, write_err = IO.pipe
      argv = [*base_argv, *cmd_argv]
      DEFAULT_LOGGER.info("Running as #{user}: #{[*base_argv, *cmd_argv].join(' ')}")

      pid = Kernel.fork do
        read_out.close
        read_err.close

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
        Kernel.exec(env, *argv, unsetenv_others: true, close_others: true, out: write_out, err: write_err)
      end

      write_out.close
      write_err.close
      _, status = Process.wait2(pid)
      stdout = read_out.read
      stderr = read_err.read

      DEFAULT_LOGGER.info("Exited: #{status.exitstatus}")
      level = (status.success? ? Logger::DEBUG : Logger::ERROR)
      DEFAULT_LOGGER.add level, <<~ERROR

        STDOUT:
        #{stdout}

        STDERR:
        #{stderr}
      ERROR
      SystemCommand.new(stdout: stdout, stderr: stderr, code: status.exitstatus)
    ensure
      read_out.close unless read_out.closed?
      write_out.close unless write_out.closed?
      read_err.close unless read_err.closed?
      write_err.close unless write_err.closed?
    end
  end

  def self.index_sessions(user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} list").call(user: user)
  end

  def self.find_session(id, user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} show").call(id, user: user)
  end

  def self.start_session(desktop, user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} start").call(desktop, user: user)
  end

  def self.webify_session(id, user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} webify").call(id, user: user)
  end

  def self.kill_session(id, user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} kill").call(id, user: user)
  end

  def self.clean_session(id, user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} clean").call(id, user: user)
  end

  def self.verify_desktop(desktop, user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} verify").call(desktop, user: user)
  end

  def self.avail_desktops(user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} avail").call(user: user)
  end

  def self.version(user:)
    Builder.new("#{FlightDesktopRestAPI.config.desktop_command} --version").call(user: user)
  end

  property :stdout, default: ''
  property :stderr, default: ''
  property :code,   default: 255

  def success?
    code == 0
  end

  def raise_unless_successful
    return if success?
    raise InternalServerError
  end
end

