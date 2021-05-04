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

require 'base64'
require 'time'

class Session < Hashie::Trash
  include Hashie::Extensions::Dash::Coercion

  def self.index(user:, reload: true)
    cmd = SystemCommand.index_sessions(user: user)
    if cmd.success?
      # Load the sessions and return if skipping the reload
      sessions = cmd.stdout.split("\n").map do |line|
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
          created_at: parts[9],
          last_accessed_at: parts[10],
          user: user
        )
      end
      return sessions unless reload

      # Checks if any sessions need to be "webified" or return
      ids = sessions.select { |s| s.webport == '0' && s.state == 'Active' }.map(&:id)
      return sessions if ids.empty?

      # Webify the sessions
      # NOTE: Consider refactoring flight-desktop to implicitly webify all
      #       required sessions. Running 'webify_session' once per session
      #       adds unnecessary overhead. This could be done in a single command
      ids.each { |id| SystemCommand.webify_session(id, user: user) }

      # Reload the sessions to get the port
      index(user: user, reload: false)
    else
      raise InternalServerError
    end
  end

  def self.find(id, reload: true, user:)
    cmd = SystemCommand.find_session(id, user: user)
    if cmd.success?
      session = build_from_output(cmd.stdout.split("\n"), user: user)

      # Stop the recursion
      return session unless reload

      # Checks if the session needs to be webified
      return session unless session.webport == '0' && session.state == 'Active'

      # Webify the session and reload
      SystemCommand.webify_session(id, user: user)
      find(id, reload: false, user: user)
    else
      # Technically multiple errors conditions could cause the command to fail
      # However the exit code is always the same.
      #
      # It is assumed that the primary reason for the error is because the session is missing
      nil
    end
  end

  def self.build_from_output(lines, user:)
    lines = lines.split("\n") if lines.is_a?(String)
    data = lines.each_with_object({}) do |line, memo|
      parts = line.split(/\t/, 2)
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
      when 'State'
        :state
      when 'Web Socket Port'
        :webport
      when 'Created At'
        :created_at
      when 'Last Accessed At'
        :last_accessed_at
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
  property :created_at, transform_with: ->(time) {
    case time
    when Time
      time
    when NilClass, ''
      # The API assumes the 'created_at' time is always set, thus
      # it defaults to now.
      # NOTE: The underlying CLI will no longer return inconsistent
      # created_at and last_accessed_at times.
      Time.now
    else
      Time.parse(time.to_s)
    end
  }
  property :last_accessed_at, transform_with: ->(time) {
    case time
    when Time
      time
    when NilClass, ''
      nil
    else
      Time.parse(time.to_s)
    end
  }
  property :cache_dir
  property :screenshot

  def self.loader(*a)
    new(*a).tap do |session|
      session.cache_dir ||= SystemCommand::Handlers.load_cache_dir(user: session.user)
      session.created_at ||= begin
        path = File.join(session.cache_dir,
                         'flight/desktop/sessions',
                         session.id,
                         'metadata.yml')
        File::Stat.new(path).ctime
      end
      session.last_accessed_at ||= begin
        path = File.join(session.cache_dir,
                         'flight/desktop/sessions',
                         session.id,
                         'session.log')
        File::Stat.new(path).ctime if File.exists? path
      end
    end
  end

  def load_screenshot
    self.screenshot = Screenshot.new(self).read || false
  end

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
      'state' => state,
      'created_at' => created_at.rfc3339,
      'last_accessed_at' => last_accessed_at&.rfc3339
    }.tap do |h|
      h['screenshot'] = Base64.encode64 screenshot if screenshot
      h['screenshot'] = nil if screenshot == false
    end
  end

  def kill(user:)
    cmd = SystemCommand.kill_session(id, user: user)
    return true if cmd.success?
    cmd = SystemCommand.clean_session(id, user: user)
    return true if cmd.success?
    raise InternalServerError.new(details: 'failed to delete the session')
  end

  def clean(user:)
    if SystemCommand.clean_session(id, user: user).success?
      true
    else
      raise InternalServerError.new(details: 'failed to clean the session')
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
  property :homepage

  def to_json
    as_json.to_json
  end

  def as_json(_ = {})
    {
      'id' => name,
      'verified' => verified?,
      'summary' => summary,
      'homepage' => homepage
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
    Session.build_from_output(cmd.stdout.split("\n"), user: user)
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

  def read!
    read || raise(NotFound.new(id: session.id, type: 'screenshot'))
  end

  def read
    p = self.class.path(session.user, session.id)
    File.exists?(p) ? File.read(p) : nil
  end
end

