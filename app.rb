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

require 'sinatra'

configure do
  set :bind, '0.0.0.0'
  set :dump_errors, false
  set :raise_errors, true
  set :show_exceptions, false

  enable :cross_origin if FlightDesktopRestAPI.config.cors_domain
end

not_found do
  { errors: [NotFound.new] }.to_json
end

# Converts HttpError objects into their JSON representation. Each object already
# sets the response code
error(HttpError) do
  e = env['sinatra.error']
  level = (e.is_a?(UnexpectedError) ? Logger::ERROR : Logger::DEBUG)
  DEFAULT_LOGGER.add level, e.full_message
  { errors: [e] }.to_json
end

# Catches all other errors and returns a generic Internal Server Error
error(StandardError) do
  DEFAULT_LOGGER.error env['sinatra.error'].full_message
  { errors: [UnexpectedError.new] }.to_json
end

# Sets the response headers
before do
  content_type 'application/json'

  response.headers['Access-Control-Allow-Origin'] = FlightDesktopRestAPI.config.cors_domain if FlightDesktopRestAPI.config.cors_domain
end

helpers do
  attr_accessor :current_user
end

# Validates the user's credentials from the authorization header
before do
  next if env['REQUEST_METHOD'] == 'OPTIONS'
  auth = FlightDesktopRestAPI.config.auth_decoder.decode(
    request.cookies[FlightDesktopRestAPI.app.config.sso_cookie_name],
    env['HTTP_AUTHORIZATION']
  )
  raise Unauthorized unless auth.valid?
  self.current_user = auth.username
  raise RootForbidden if current_user == 'root'
end

# Checks the request Content-Type is application/json where appropriate
# Saves the input JSON as if it was a form input
# Adapted from:
# https://raw.githubusercontent.com/rack/rack-contrib/master/lib/rack/contrib/post_body_content_type_parser.rb
before do
  next if ['GET', 'HEAD', 'OPTIONS'].include? env['REQUEST_METHOD']
  if env['CONTENT_TYPE'] == 'application/json'
    begin
      io = env['rack.input']
      body = io.read
      io.rewind
      json = body.empty? ? {} : JSON.parse(body, create_additions: false)
      raise BadRequest.new(detail: 'the body must be a JSON hash') unless json.is_a?(Hash)
      json.each { |k, v| params[k] ||= v }
    rescue JSON::ParserError
      raise BadRequest.new(detail: 'failed to parse body as JSON')
    end
  else
    raise UnsupportedMediaType
  end
end

if FlightDesktopRestAPI.config.cors_domain
  options "*" do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Methods"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept"
    status 200
    ''
  end
end

namespace '/ping' do
  get do
    content_type 'text/plain'
    status 200
    'OK'
  end
end

namespace '/configs' do
  get('/user') do
    # There is no fetch command for configs in flight-desktop, only set
    DesktopConfig.update(user: current_user).to_json
  end

  patch('/user') do
    update = params.slice('geometry', 'desktop')
                   .map { |k, v| [k.to_sym, v] }
                   .to_h
    DesktopConfig.update(**update, user: current_user).to_json
  end
end

namespace '/desktops' do
  get do
    { 'data' => Desktop.index }.to_json
  end

  get('/:id') do
    id = params[:id]
    desktop = Desktop[id].tap do |d|
      raise NotFound.new(type: 'desktop', id: id) unless d
    end
    desktop.to_json
  end
end

namespace '/sessions' do
  helpers do
    def desktop_param
      params[:desktop].tap do |d|
        next if d
        raise BadRequest.new(detail: 'the "desktop" attribute is required by this request')
      end
    end

    def current_desktop
      Desktop[desktop_param].tap do |d|
        raise NotFound.new(type: 'desktop', id: desktop_param) unless d
      end
    end

    def include_screenshot?
      params[:include] == 'screenshot'
    end
  end

  get do
    {
      'data' => Session.index(user: current_user)
                       .each { |s| s.load_screenshot if include_screenshot? }
    }.to_json
  end

  post do
    status 201
    if params[:desktop]
      current_desktop.start_session!(user: current_user).to_json
    else
      Session.start_default(user: current_user).to_json
    end
  end

  namespace('/:id') do
    helpers do
      def id_param
        params[:id]
      end

      def current_session
        Session.find(id_param, user: current_user).tap do |s|
          next if s
          raise NotFound.new(type: 'session', id: id_param)
        end
      end
    end

    get do
      current_session.tap { |s| s.load_screenshot if include_screenshot? }
                     .to_json
    end

    get '/screenshot.png' do
      content_type 'image/png'
      Screenshot.new(current_session).read!
    end

    delete do
      status 204
      case params.fetch('strategy', 'kill')
      when 'kill'
        current_session.kill(user: current_user)
      when 'clean'
        current_session.clean(user: current_user)
      else
        raise BadRequest.new(detail: "unsupported strategy: #{params['strategy']}")
      end
    end
  end
end

