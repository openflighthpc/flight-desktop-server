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

# NOTE: All desktops must be stubbed in the spec
return if ENV['RACK_ENV'] == 'test'

# Determines at which interval the verify command should run
verify_interval = FlightDesktopRestAPI.config.refresh_rate/ FlightDesktopRestAPI.config.short_refresh_rate
if verify_interval < 1
  raise 'The refresh_rate must be greater than, or equal to, the short_refresh_rate!'
end
first = true
count = 0

# Periodically reload and verify the desktops
opts = {
  execution_interval: FlightDesktopRestAPI.config.short_refresh_rate,
  timeout_interval: (FlightDesktopRestAPI.config.short_refresh_rate - 1),
  run_now: true
}
Concurrent::TimerTask.new(**opts) do |task|
  models = SystemCommand.avail_desktops(user: ENV['USER'])
                        .tap(&:raise_unless_successful)
                        .stdout
                        .each_line.map do |line|
    data = line.split("\t")
    home = data[2].empty? ? nil : data[2]
    verified = data[3] == 'Verified'
    Desktop.new(name: data[0], summary: data[1], homepage: home, verified: verified)
  end

  # Set the initial state of the desktops
  hash = models.map { |m| [m.name, m] }.to_h
  Desktop.instance_variable_set(:@cache, hash)

  # Preform the additional verification step (when required)
  if count == 0
    models.each { |m| m.verify_desktop(user: ENV['USER']) }
    hash = models.map { |m| [m.name, m] }.to_h
    Desktop.instance_variable_set(:@cache, hash)
  end

  DEFAULT_LOGGER.info "Finished #{'re' unless first}loading the desktops"
  first = false
  count = (count + 1) % verify_interval
end.execute
