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

ENV['RACK_ENV'] = 'test'

require 'rake'
load File.expand_path('../Rakefile', __dir__)
Rake::Task[:require].invoke

module RSpecSinatraMixin
  include Rack::Test::Methods

  def app()
    Sinatra::Application.new
  end
end

RSpec.configure do |c|
	# Include the Sinatra helps into the application
	c.include RSpecSinatraMixin

  def parse_last_request_body
    Hashie::Mash.new(JSON.pase(last_request.body))
  end

  def parse_last_response_body
    Hashie::Mash.new(JSON.parse(last_response.body))
  end

  def last_error
    last_request.env['sinatra.error']
  end

  # Disable the SystemCommand::Builder from creating commands
  # This forces all system commands to be mocked
  c.before do
    allow(SystemCommand::Builder).to receive(:new).and_wrap_original do |_, *a|
      raise NotImplementedError, <<~ERROR.squish
        Running system commands is not supported in the spec. The following
        needs to be stubbed: '#{a.first}'
      ERROR
    end
  end
end

