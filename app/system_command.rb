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

class SystemCommand < Hashie::Dash
  # TODO: Build shell sanitization into the Renderer
  class Builder < Hashie::Mash
    attr_reader :__cmd__

    def initialize(cmd, **opts)
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

