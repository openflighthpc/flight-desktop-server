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

require 'spec_helper'

# Demo Route for error mocking
module StubError
  def self.call; end

  def self.stub(ex)
    ex.allow(self).to ex.receive(:call).and_wrap_original { yield if block_given? }
  end
end

Sinatra::Application.get('/test-error-handling') do
  StubError.call
end

RSpec.describe 'Error Handling' do
  def get_test_error_page
    get '/test-error-handling'
  end

  def expect_internal_server_error
    error = parse_last_response_body['errors'].first
    expect(error['code']).to eq('Internal Server Error')
    expect(error['status']).to eq(last_response.status.to_s)
    expect(error.keys).not_to include('details')
  end

  it 'handles internal server errors' do
    StubError.stub(self) { raise InternalServerError }
    get_test_error_page
    expect_internal_server_error
  end

  it 'handles unexpected errors' do
    StubError.stub(self) { raise StandardError }
    get_test_error_page
    expect_internal_server_error
  end
end

