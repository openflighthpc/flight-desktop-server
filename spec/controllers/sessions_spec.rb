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

RSpec.describe '/sessions' do
  subject { raise NotImplementedError, 'the spec has not defined its subject' }
  let(:url_id) { raise NotImplementedError, 'the spec :url_id has not been set' }
  let(:sessions) { raise NotImplementedError, 'the spec has not defined sessions' }

  let(:successful_cache_dir_stub) do
    SystemCommand.new(stderr: '', code: 0, stdout: "/home/#{username}/.cache\n")
  end

  let(:successful_find_stub) do
    SystemCommand.new(
      stderr: '', code: 0, stdout: <<~STDOUT
        Identity        #{subject.id}
        Type    #{subject.desktop}
        Host IP #{subject.ip}
        Hostname        #{subject.hostname}
        Port    #{subject.port}
        Display IGNORE_THIS_FIELD
        Password        #{subject.password}
      STDOUT
    )
  end

  let(:index_multiple_stub) do
    stdout = sessions.each_with_index.map do |s, idx|
      "#{s.id}\t#{s.desktop}\t#{s.hostname}\t#{s.ip}\t#{idx}\t#{s.port}\t#{s.webport}\t#{s.password}\t#{s.state}"
    end.join("\n")
    SystemCommand.new(stdout: stdout, stderr: '', code: 0)
  end

  shared_examples 'sessions error when missing' do
    context 'when the command fails' do
      let(:url_id) { 'missing' }

      before do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(exit_213_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(exit_213_stub)
        make_request
      end

      # NOTE: This is only temporarily returning 500 whilst index_sessions is being used!
      # Notionally it should never fail but return an empty list. If and when find_session
      # is reinstated, this should be revert to 404
      it 'returns 500' do
        expect(last_response.status).to be(500)
      end
    end

    # NOTE: This is only required whilst find_by_indexing is in use
    # If and when find_session is used again, this spec can be removed
    context 'when the index does not include the session' do
      let(:url_id) { '6bbf0bcf-4ac0-4d09-af10-ceef1527c087' }

      let(:other1) do
        Session.new(
          id: "a3207f38-40ed-48df-9a59-4b54f840ced1",
          desktop: "gnome",
          ip: '10.1.1.1',
          hostname: 'example.com',
          port: 5923,
          webport: 41401,
          password: 'b187668d',
          state: 'Active'
        )
      end

      let(:other2) do
        Session.new(
          id: "2b29efce-2717-45f1-a982-f090cdbf7435",
          desktop: "gnome",
          ip: '10.1.1.2',
          hostname: 'example.com',
          port: 5924,
          webport: 41402,
          password: '8b17ba61',
          state: 'Active'
        )
      end

      let(:sessions) { [other1, other2] }

      before do
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        make_request
      end

      it 'returns 404' do
        expect(last_response).to be_not_found
      end
    end
  end

  describe 'GET /sessions' do
    def make_request
      standard_get_headers
      get '/sessions'
    end

    context 'without any running sessions' do
      before do
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(exit_0_stub)
        make_request
      end

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'returns an empty array' do
        expect(parse_last_response_body.data).to eq([])
      end
    end

    context 'when the index system command fails' do
      before do
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(exit_213_stub)
        make_request
      end

      it 'returns 500' do
        expect(last_response.status).to be(500)
      end
    end

    context 'with multiple running sessions' do
      let(:sessions) do
        [
          {
            id: '0362d58b-f29a-4b99-9a0a-277c902daa55',
            desktop: 'gnome',
            hostname: 'example.com',
            ip: '10.101.0.1',
            port: 5901,
            webport: 41301,
            password: 'GovCosh6',
            state: 'Active'
          },
          {
            id: '135036a4-0471-4014-ab56-7b65648895df',
            desktop: 'kde',
            hostname: 'example.com',
            ip: '10.101.0.2',
            port: 5902,
            webport: 41302,
            password: 'Dinzeph3',
            state: 'Active'
          },
          {
            id: '135c07c2-5c9f-4e32-9372-a408d2bbe621',
            desktop: 'xfce',
            hostname: 'example.com',
            ip: '10.101.0.3',
            port: 5903,
            webport: 41303,
            password: '5wroliv5',
            state: 'Active'
          }
        ].map { |h| Session.new(**h) }
      end

      before do
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        make_request
      end

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'returns the sessions as JSON' do
        expect(parse_last_response_body.data).to eq(sessions.as_json)
      end
    end

    context 'with a broken session' do
      let(:broken_index_stub) do
        SystemCommand.new(stderr: '', code: 0, stdout: <<~STDOUT)
          #{id}\t\t\t\t\t\t\t\tBroken\n
        STDOUT
      end

      let(:id) { '3d17d06e-701a-11ea-a14f-52540005505a' }

      before do
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(broken_index_stub)
        make_request
      end

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'returns a empty-ish response' do
        data = parse_last_response_body.data.first.reject { |_, v| v.nil? }
        expect(data.delete('id')).to eq(id)
        expect(data.delete('state')).to eq('Broken')
        expect(data).to be_empty
      end
    end
  end

  describe 'GET /sessions/:id' do
    def make_request
      standard_get_headers
      get "/sessions/#{url_id}"
    end

    include_examples 'sessions error when missing'

    context 'with a stubbed existing session' do
      subject do
        Session.new(
          id: "11a8e4a1-9371-4b60-8d00-20441a4f2612",
          desktop: "gnome",
          ip: '10.1.0.1',
          hostname: 'example.com',
          port: 5956,
          webport: 41304,
          password: '97InM80d',
          state: 'Active'
        )
      end

      let(:other1) do
        Session.new(
          id: "d5255917-c8c3-4d00-bf1c-546445f8956f",
          desktop: "gnome",
          ip: '10.1.0.2',
          hostname: 'example.com',
          port: 5957,
          webport: 41305,
          password: 'df18bb48',
          state: 'Active'
        )
      end

      let(:other2) do
        Session.new(
          id: "dc17e3d0-ed68-493f-a7ec-5029310cd0f6",
          desktop: "gnome",
          ip: '10.1.0.3',
          hostname: 'example.com',
          port: 5957,
          webport: 41306,
          password: 'a8fd740d',
          state: 'Active'
        )
      end

      let(:sessions) { [other1, subject, other2] }

      before do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        make_request
      end

      context 'when using the full UUID' do
        let(:url_id) { subject.id }

        it 'returns okay' do
          expect(last_response).to be_ok
        end

        it 'returns the subject as JSON' do
          expect(parse_last_response_body).to eq(subject.as_json)
        end
      end

      # NOTE: The future of the "fuzzy id" is yet TBD
      # ATM they are not supported due to find_by_indexing
      # Revisit as required
      context 'when using a fuzzy id' do
        let(:url_id) { subject.id.split('-').first }

        it 'returns 404' do
          expect(last_response).to be_not_found
        end
      end
    end
  end

  describe 'GET /sessions/:id/screenshot.png' do
    def make_request
      standard_get_headers
      get "/sessions/#{url_id}/screenshot.png"
    end

    include_examples 'sessions error when missing'

    context 'with a missing screenshot' do
      subject do
        Session.new(
          id: "72e2f8d3-dea5-465c-b8d5-67336c7f8680",
          desktop: "xfce",
          ip: '10.101.0.4',
          hostname: 'example.com',
          port: 5942,
          webport: 41307,
          password: 'b74fbb5d',
          state: 'Active'
        )
      end

      let(:sessions) { [subject] }

      let(:url_id) { subject.id }

      it 'returns 404' do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        expect(Screenshot).to receive(:path).with(username, url_id)
        FakeFS.with { make_request }
        expect(last_response).to be_not_found
      end
    end

    context 'when getting the cache directory fails' do
      subject do
        Session.new(
          id: "72e2f8d3-dea5-465c-b8d5-67336c7f8680",
          desktop: "xfce",
          ip: '10.101.0.4',
          hostname: 'example.com',
          port: 5942,
          webport: 41308,
          password: 'b74fbb5d',
          state: 'Active'
        )
      end

      let(:sessions) { [subject] }

      let(:url_id) { subject.id }

      it 'returns 500' do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(exit_213_stub)
        FakeFS.with { make_request }
        expect(last_response.status).to be(500)
      end
    end

    context 'with a existing screenshot' do
      subject do
        Session.new(
          id: "6d1f1937-3812-486b-9bfb-38c3c85b34e9",
          desktop: "kde",
          ip: '10.101.0.5',
          hostname: 'example.com',
          port: 5944,
          webport: 41309,
          password: '29d20f04',
          state: 'Active'
        )
      end

      let(:sessions) { [subject] }

      let(:screenshot) do
        <<~SCREEN
          A `bunch`, of "random" characters! &&**?><>}{[]££""''
          ++**--!!"!£"$^£&"£$£"$%$&**()()?<>~@:{}@~}{@{{P

          ¯\_(ツ)_/¯
        SCREEN
      end

      let(:url_id) { subject.id }

      before do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        FakeFS.with do
          path = Screenshot.path(username, subject.id)
          FileUtils.mkdir_p(File.dirname path)
          File.write(path, screenshot)
          make_request
        end
      end

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'sets the Content-Type correctly' do
        expect(last_response.headers['Content-Type']).to eq('image/png')
      end

      it 'responds with the image' do
        expect(last_response.body).to eq(screenshot)
      end
    end
  end

  describe 'POST /sessions' do
    let(:desktop) { raise NotImplementedError, 'the spec :desktop has not been set' }

    let(:successful_create_stub) do
      SystemCommand.new(
        code: 0, stderr: '',
        stdout: <<~STDOUT
          Starting a '#{subject.desktop}' desktop session:

             > ✅ Starting session

          A '#{subject.desktop}' desktop session has been started.
          Identity        #{subject.id}
          Type    #{subject.desktop}
          Host IP #{subject.ip}
          Hostname        #{subject.hostname}
          Port    #{subject.port}
          Display IGNORE_THIS_FIELD
          Password        #{subject.password}
        STDOUT
      )
    end

    let(:unknown_create_stub) do
      SystemCommand.new(
        code: 1, stdout: '', stderr: "flight desktop: unknown desktop type: #{desktop}\n"
      )
    end

    let(:unverified_create_stub) do
      SystemCommand.new(
        code: 1, stdout: '', stderr: "flight desktop: Desktop type '#{desktop}' has not been verified\n"
      )
    end

    let(:successful_verified_stub) do
      SystemCommand.new(
        code: 0, stderr: '', stdout: <<~STDOUT
          Verifying desktop type #{desktop}:

             > ✅ Package: #{desktop}-package
             > ✅ Package: #{desktop}-other-package

          Desktop type #{desktop} has been verified.

        STDOUT
      )
    end

    let(:unsuccessful_verified_stub) do
      SystemCommand.new(
        code: 0, stderr: '', stdout: <<~STDOUT
          Verifying desktop type #{desktop}:

             > ❌ Repository: #{desktop}
             > ❌ Package: #{desktop}-package

          Desktop type chrome has missing prerequisites:

           * Package repo: #{desktop}
           * Package: #{desktop}-package

          Before this desktop type can be used, it must be prepared using the
          'prepare' command, i.e.:

            flight desktop prepare #{desktop}

        STDOUT
      )
    end

    def make_request
      standard_post_headers
      post '/sessions', { desktop: desktop }.to_json
    end

    context 'when the request sends a missing desktop' do
      let(:desktop) { 'missing' }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unknown_create_stub)
        make_request
      end

      it 'returns 404' do
        expect(last_response).to be_not_found
      end
    end

    context 'when the request does not send a desktop' do
      before do
        standard_post_headers
        post '/sessions'
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end
    end

    context 'when creating a verified desktop session' do
      subject do
        Session.new(
          id: '3335bb08-8d91-40fd-a973-da05bdbf3636',
          desktop: desktop,
          ip: '10.1.0.2',
          hostname: 'example.com',
          port: 5905,
          webport: 41310,
          password: 'WakofEb6',
          state: 'Active'
        )
      end

      let(:desktop) { define_desktop('verified').name }

      before do
        expect(SystemCommand).not_to receive(:verify_desktop)
        allow(SystemCommand).to receive(:start_session).and_return(successful_create_stub)
        make_request
      end

      it 'returns 201' do
        expect(last_response).to be_created
      end

      # NOTE: BUG NOTICE!
      # The create method does not return the websockify port or the state
      it 'returns the subject as JSON' do
        expect(parse_last_response_body).to eq(
          subject.as_json.merge('port' => nil, 'state' => nil)
        )
      end
    end

    context 'when creating a unverified desktop' do
      let(:desktop) { define_desktop('unverified', verified: false).name }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
      end

      it 'attempts to verify the desktop' do
        expect(SystemCommand).to receive(:verify_desktop).with(desktop, anything)
        make_request
      end
    end

    # This checks the error handling if the verify command fails. It does not mean the
    # desktop is unverified. In cases where the desktop is unverified, the command exits 0
    context 'when verifying a desktop fails' do
      let(:desktop) { define_desktop('unverified', verified: false).name }

      before do
        expect(SystemCommand).to receive(:verify_desktop).and_return(exit_213_stub)

        make_request
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end
    end

    # This is an odd case that shouldn't ever be hit. Notionally the create should succeed
    # as the desktop has already been verified. However due to the string processing involved,
    # a edge case could be triggered. Therefore it must explicitly return a InternalServerError
    context 'when the create gives a false-postive unverfied response' do
      let(:desktop) { define_desktop('unverified', verified: false).name }

      let(:already_verified_stub) do
        SystemCommand.new(
          code: 0, stderr: '', stdout: "Desktop type #{desktop} has already been verified.")
      end

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
        allow(SystemCommand).to receive(:verify_desktop).and_return(already_verified_stub)
        make_request
      end

      it 'returns 500' do
        expect(last_response.status).to be(500)
      end
    end

    # This tests when the verify command exits 0 but the desktop is otherwise unverified
    context 'when a desktop is successfully unverified' do
      let(:desktop) { define_desktop('success-unverified', verified: false).name }

      before do
        allow(SystemCommand).to receive(:verify_desktop).and_return(unsuccessful_verified_stub)

        make_request
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end

      it 'returns Desktop Not Prepared' do
        expect(parse_last_response_body.errors.first.code).to eq('Desktop Not Prepared')
      end
    end

    context 'with an unverifing desktop when the start always errors' do
      let(:desktop) { define_desktop('succeed-verified', verified: false).name }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
        allow(SystemCommand).to receive(:verify_desktop).and_return(successful_verified_stub)

        make_request
      end

      it 'returns 500' do
        expect(last_response.status).to be(500)
      end
    end

    context 'when an unverified desktop cache status is incorrect and verification fails' do
      subject do
        Session.new(
          id: '9633d854-1790-43b2-bf06-f6dc46bb4859',
          desktop: desktop,
          ip: '10.1.0.3',
          hostname: 'example.com',
          port: 5906,
          webport: 41311,
          password: 'ca77d490',
          state: 'Active'
        )
      end

      let(:desktop_model) { define_desktop('will-not-be-created', verified: true) }
      let(:desktop) { desktop_model.name }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
        allow(SystemCommand).to receive(:verify_desktop).and_return(unsuccessful_verified_stub)
        make_request
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end

      it 'the desktop is flagged as unverified' do
        expect(desktop_model).not_to be_verified
      end
    end

    context 'when verifing a desktop command succeeds and the retry also succeeds' do
      subject do
        Session.new(
          id: '9633d854-1790-43b2-bf06-f6dc46bb4859',
          desktop: desktop,
          ip: '10.1.0.3',
          hostname: 'example.com',
          port: 5906,
          webport: 41311,
          password: 'ca77d490',
          state: 'Active'
        )
      end

      let(:desktop_model) { define_desktop('will-be-created', verified: false) }
      let(:desktop) { desktop_model.name }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(
          unverified_create_stub, successful_create_stub
        )
        allow(SystemCommand).to receive(:verify_desktop).and_return(successful_verified_stub)

        make_request
      end

      it 'returns 201' do
        expect(last_response).to be_created
      end

      # NOTE: BUG NOTICE!
      # The create method does not return the websockify port or the state
      it 'returns the subject as JSON' do
        expect(parse_last_response_body).to eq(
          subject.as_json.merge('port' => nil, 'state' => nil)
        )
      end

      it 'sets the desktop as verified' do
        expect(desktop_model).to be_verified
      end
    end
  end

  describe 'DELETE /session/:id' do
    subject do
      Session.new(
        id: 'ed36dedb-5003-4765-b8dc-0c1cc2922dd7',
        desktop: 'gnome',
        ip: '10.1.0.4',
        hostname: 'example.com',
        port: 5906,
        webport: 41312,
        password: 'a33ff119',
        state: 'Active'
      )
    end

    let(:sessions) { [subject] }

    let(:url_id) { subject.id }

    def make_request
      standard_get_headers
      delete "/sessions/#{url_id}"
    end

    include_examples 'sessions error when missing'

    context 'when the kill succeeds' do
      before do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        allow(SystemCommand).to receive(:kill_session).and_return(exit_0_stub)
        make_request
      end

      it 'returns 204' do
        expect(last_response).to be_no_content
      end

      it 'returns an empty body' do
        expect(last_response.body).to be_empty
      end
    end

    context 'when the kill fails' do
      before do
        # NOTE: "Temporarily" out of use
        # allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
        allow(SystemCommand).to receive(:echo_cache_dir).and_return(successful_cache_dir_stub)
        allow(SystemCommand).to receive(:index_sessions).and_return(index_multiple_stub)
        allow(SystemCommand).to receive(:kill_session).and_return(exit_213_stub)
        make_request
      end

      it 'returns 500' do
        expect(last_response.status).to be(500)
      end
    end
  end
end

