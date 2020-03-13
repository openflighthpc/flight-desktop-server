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

require 'erb'
require 'shellwords'
require 'open3'

class SystemCommand < Hashie::Dash
  class Builder
    attr_reader :base_argv

    def initialize(cmd)
      @base_argv ||= cmd.split("\s")
    end

    # TODO: Correctly setup the environment with the user
    # NOTE: The Bundler.with_clean_env may not be required once the env is setup correctly
    def call(*argv, user:)
      Bundler.with_clean_env do
        stdout, stderr, status = Open3.capture3(*base_argv, *argv)
        return SystemCommand.new(stdout: stdout, stderr: stderr, code: status.exitstatus)
      end
    end
  end

  # NOTE: This system command is required to determine the cache directory the screenshot
  # is stored within. This is required as it is specific to each user and most be done
  # as a system call.
  #
  # System commands are executed without a shell to prevent injection attacks. However
  # a shell is required to expand the environment variables. This is "OK" as the method
  # does not have any inputs. However the bash command needs to be executed manually.
  #
  # This design pattern is only required as `flight desktop` does not provide a method
  # to get the screenshot. This does violate the law of demeter and should be rectified:
  # See https://en.wikipedia.org/wiki/Law_of_Demeter
  #
  # NOTE: SECURITY NOTICE
  # echo_cache_dir MUST NOT take any inputs. It is executing through a shell and therefore
  # it is possible to preform an injection attack
  def self.echo_cache_dir(user:)
    Builder.new("bash -c").call('echo ${XDG_CACHE_HOME:-$HOME/.cache}', user: user)
  end

  def self.index_sessions(user:)
    Builder.new('flight desktop list').call(user: user)
  end

  def self.find_session(id, user:)
    Builder.new("flight desktop show").call(id, user: user)
  end

  def self.start_session(desktop, user:)
    Builder.new("flight desktop start").call(desktop, user: user)
  end

  def self.kill_session(id, user:)
    Builder.new("flight desktop kill").call(id, user: user)
  end

  def self.prepare_desktop(desktop, user:)
    Builder.new("flight desktop prepare").call(desktop, user: user)
  end

  property :stdout, default: ''
  property :stderr, default: ''
  property :code,   default: 255

  def success?
    code == 0
  end
end

