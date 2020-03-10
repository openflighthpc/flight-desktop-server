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

# NOTE: DEVELOPERS README
# All system commands should be executed through a SystemCommand::Builder
# The builder takes the command as an ERB template and associated keys
#
# This allows it to "validate" the inputs before substituting them into the
# command. Inputs are only valid if they match their shell escaped version.
# Invalid inputs will trigger a user facing error and associated description
#
# BEWARE:
# * The error message is user facing! This means any value may be exposed to
#   in the error response
# * This is not input sanitization! Any requests with invalid inputs are
#   rejected instead of "corrected"
#
# RECOMMENDATION:
# If sensitive information needs to be passed through the system command then
# the Builder needs to be refactored. Possible have a 'sensitive' top level
# key for these values?

class SystemCommand < Hashie::Dash
  class Builder < Hashie::Mash
    attr_reader :__cmd__

    def initialize(cmd, **opts)
      opts.each do |key, value|
        next if value == Shellwords.escape(value)
        raise InvalidCommandInput.new(detail: <<~ERROR.squish)
          Cowardly refusing to continue with the following #{key}:
          #{value}
        ERROR
      end
      @__cmd__ ||= cmd
      super(opts)
    end

    def __call__(user)
      # noop - eventually return instance of SystemCommand
    end

    private

    def __render__
      ERB.new(__cmd__, nil, '-').result(binding)
    end
  end

  def self.find_session(id, user:)
    Builder.cmd("flight desktop show <%= id %>", id: id).__call__(user)
  end

  property :stdout, default: ''
  property :stderr, default: ''
  property :code,   default: 255
end

