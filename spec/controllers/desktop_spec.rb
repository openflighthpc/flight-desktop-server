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

RSpec.describe '/desktops' do
  describe 'GET /desktops' do
    def make_request
      standard_get_headers
      get '/desktops'
    end

    context 'without any desktops' do
      before { make_request }

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'returns an empty data array' do
        expect(parse_last_response_body.data).to eq([])
      end
    end

    context 'with desktops' do
      let(:hashes) do
        [
          { 'id'  => 'verified', 'verified' => true },
          { 'id'  => 'unverified', 'verified' => false }
        ]
      end

      let(:desktops) do
        hashes.map { |h| define_desktop(h['id'], verified: h['verified']) }
      end

      before do
        desktops
        make_request
      end

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'returns the desktops' do
        matchers = hashes.map { |h| a_hash_including(h) }
        expect(parse_last_response_body.data).to match(matchers)
      end
    end
  end
end

