#==============================================================================
# Copyright (C) 2021-present Alces Flight Ltd.
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

module FlightDesktopRestAPI
  class Configuration
    extend FlightConfiguration::RackDSL

    root_path File.expand_path('../..', __dir__)
    application_name 'flight-desktop-restapi'

    attribute 'bind_address',       default: 'tcp://127.0.0.1:915'
    attribute 'cors_domain',        required: false
    attribute 'refresh_rate',       default: 300
    attribute 'full_refresh',       default: 12
    attribute 'log_level',          default: 'info'
    attribute 'shared_secret_path', default: 'etc/shared-secret.conf',
                                    transform: relative_to(root_path)
    attribute 'sso_cookie_name',    default: 'flight_login'
    attribute 'desktop_command',    default: ->() do
      # TODO: Update to 'Flight.root' once migrated to the new version of
      # flight_configuration
      root = ENV.fetch('flight_ROOT', '/opt/flight')
      "#{File.join(root, 'bin/flight')} desktop"
    end

    def auth_decoder
      @auth_decoder ||= FlightAuth::Builder.new(shared_secret_path)
    end
  end
end

