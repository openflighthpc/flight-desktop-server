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

require 'base64'

class Session < Hashie::Trash
  include Hashie::Extensions::Dash::Coercion

  def self.index(user:)
    cmd = SystemCommand.index_sessions(user: user)
    if cmd.success?
      cmd.stdout.split("\n").map do |line|
        parts = line.split("\t").map { |p| p.empty? ? nil : p }
        new(
          id: parts[0],
          desktop: parts[1],
          hostname: parts[2],
          ip: parts[3],
          port: parts[5],
          webport: parts[6],
          password: parts[7],
          state: parts[8],
          user: user
        )
      end
    else
      raise InternalServerError
    end
  end

  # NOTE: This is a "temporary" method which will find a session using the index
  # command. This work around is required b/c indexing returns the webport but
  # the find command does not.
  #
  # Remove this when it becomes obsolete
  def self.find_by_indexing(id, user:)
    sessions = index(user: user)
    sessions.find { |s| s.id == id }
  end

  # NOTE: The flight desktop command generates a UUID for each session, however
  # it also allows accepts shortened versions. This means their is some "fuzziness"
  # in the ID.
  #
  # Revists as necessary, we may want to disable this
  #
  # NOTE: GOTCHA
  # This method does not return the websockify port. It is being maintained for
  # prosperity
  def self.find_by_fuzzy_id(fuzzy_id, user:)
    cmd = SystemCommand.find_session(fuzzy_id, user: user)
    return nil unless cmd.code == 0
    build_from_output(cmd.stdout, user: user)
  end

  def self.build_from_output(lines, user:)
    lines = lines.split("\n") if lines.is_a?(String)
    data = lines.each_with_object({}) do |line, memo|
      parts = line.split(/\s+/)
      value = parts.pop
      key = case parts.join(' ')
      when 'Identity'
        :id
      when 'Host IP'
        :ip
      when 'Hostname'
        :hostname
      when 'Port'
        :port
      when 'Password'
        :password
      when 'Type'
        :desktop
      else
        next # Ignore any extraneous keys
      end
      memo[key] = value
    end
    new(user: user, **data)
  end

  property :id
  property :desktop
  property :ip
  property :hostname
  property :port, coerce: String
  property :webport, coerce: String
  property :password
  property :user
  property :state

  def to_json
    as_json.to_json
  end

  def as_json(_ = {})
    {
      'id' => id,
      'desktop' => desktop,
      'ip' => ip,
      'hostname' => hostname,
      'port' => webport,
      'password' => password,
      'state' => state
    }
  end

  def kill(user:)
    cmd = SystemCommand.kill_session(id, user: user)
    if cmd.success?
      true
    else
      raise InternalServerError.new(details: 'failed to delete the session')
    end
  end
end

class Desktop < Hashie::Trash
  def self.index
    cache.values
  end

  def self.[](key)
    cache[key]
  end

  private_class_method

  # This is set during the desktop initializer
  def self.cache
    @cache ||= {}
  end

  property :name
  property :verified, default: false
  property :summary, default: ''

  def to_json
    as_json.to_json
  end

  def as_json(_ = {})
    {
      'id' => name,
      'verified' => verified?,
      'summary' => summary
    }
  end

  def verified?
    verified
  end

  # NOTE: The start_session will attempt to verify the desktop if required
  # GOTCHA: Because the system command always exits 1 on errors, the
  #         verified/ missing toggle is based on string processing.
  #
  #         This makes the toggle brittle as a minor change in error message
  #         could break the regex match. Instead `flight desktop` should be
  #         updated to return different exit codes
  def start_session!(user:)
    verify_desktop!(user: user) unless verified?
    cmd = SystemCommand.start_session(name, user: user)
    if /verified\Z/ =~ cmd.stderr
      verify_desktop!(user: user)
      cmd = SystemCommand.start_session(name, user: user)
    end
    raise InternalServerError unless cmd.success?
    Session.build_from_output(cmd.stdout.split("\n").last(7), user: user)
  end

  def verify_desktop(user:)
    cmd = SystemCommand.verify_desktop(name, user: user)
    self.verified = if /already been verified\.\Z/ =~ cmd.stdout.chomp
      true
    elsif /flight desktop prepare/ =~ cmd.stdout
      false
    elsif cmd.success?
      true
    else
      false
    end
  end

  def verify_desktop!(user:)
    raise DesktopNotPrepared unless verify_desktop(user: user)
  end
end

Screenshot = Struct.new(:session) do
  # Stored as a class method so it can be stubbed in the tests
  def self.path(username, id)
    cmd = SystemCommand.echo_cache_dir(user: username)
    cmd.raise_unless_successful
    File.join(cmd.stdout.chomp, 'flight/desktop/sessions', id, 'session.png')
  end

  def base64_encode
    Base64.encode64(read)
  end

  def read
    p = self.class.path(session.user, session.id)
    if File.exists?(p)
      File.read(p)
    else
      raise NotFound.new(id: session.id, type: 'screenshot')
    end
  end
end

