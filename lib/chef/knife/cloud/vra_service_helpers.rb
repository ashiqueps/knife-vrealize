# frozen_string_literal: true

#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/knife/cloud/helpers"

class Chef
  class Knife
    class Cloud
      module VraServiceHelpers
        include Chef::Knife::Cloud::Helpers

        def create_service_instance
          Chef::Knife::Cloud::VraService.new(username:  config[:vra_username],
                                             password:  config[:vra_password],
                                             base_url:  config[:vra_base_url],
                                             tenant:    config[:vra_tenant],
                                             page_size: config[:vra_page_size],
                                             verify_ssl: verify_ssl?)
        end

        def verify_ssl?
          !config[:vra_disable_ssl_verify]
        end

        def wait_for_request(request, wait_time = 600, refresh_rate = 2)
          print "Waiting for request to complete."

          last_status = ""

          begin
            Timeout.timeout(wait_time) do
              loop do
                request.refresh

                if request.completed?
                  print "\n"
                  break
                end

                if last_status == request.status
                  print "."
                else
                  last_status = request.status
                  print "\n"
                  print "Current request status: #{request.status}."
                end

                sleep refresh_rate
              end
            end
          rescue Timeout::Error
            ui.msg("")
            ui.error("Request did not complete in #{wait_time} seconds. Check the Requests tab in the vRA UI for more information.")
            exit 1
          end
        end

        def validate!
          check_for_missing_config_values!(:vra_username, :vra_password, :vra_base_url, :vra_tenant)
        end

        # rubocop:disable Style/GuardClause
        def check_for_missing_config_values!(*keys)
          missing = keys.select { |x| config[x].nil? }

          unless missing.empty?
            ui.error("The following required parameters are missing: #{missing.join(", ")}")
            exit(1)
          end
        end
      end
    end
  end
end
