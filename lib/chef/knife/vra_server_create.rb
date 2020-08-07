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

require "chef/knife"
require "chef/knife/cloud/server/create_command"
require "chef/knife/cloud/server/create_options"
require_relative "cloud/vra_service_options"

class Chef
  class Knife
    class Cloud
      class VraServerCreate < ServerCreateCommand
        include VraServiceHelpers
        include VraServiceOptions
        include ServerCreateOptions

        banner "knife vra server create CATALOG_ID (options)"

        deps do
          require_relative "cloud/vra_service"
          require_relative "cloud/vra_service_helpers"
        end

        option :cpus,
          long:        "--cpus NUM_CPUS",
          description: "Number of CPUs the server should have"

        option :node_ssl_verify_mode,
          long: "--node-ssl-verify-mode [peer|none]",
          description: "Whether or not to verify the SSL cert for all HTTPS requests when bootstrapping"
        option :memory,
          long:        "--memory RAM_IN_MB",
          description: "Amount of RAM, in MB, the server should have"

        option :requested_for,
          long:        "--requested-for LOGIN",
          description: "The login to list as the owner of this resource. Will default to the vra_username parameter"

        option :server_create_timeout,
          long:        "--server-create-timeout SECONDS",
          description: "number of seconds to wait for the server to complete",
          default:     600

        option :subtenant_id,
          long:        "--subtenant-id ID",
          description: 'The subtenant ID (a.k.a "business group") to list as the owner of this resource. ' \
            "Will default to the blueprint subtenant if it exists."

        option :lease_days,
          long:        "--lease-days NUM_DAYS",
          description: "Number of days requested for the server lease, provided the blueprint allows this to be specified"

        option :notes,
          long:        "--notes NOTES",
          description: "String of text to be included in the request notes."

        option :extra_params,
          long:        "--extra-param KEY=TYPE:VALUE",
          description: 'Additional parameters to pass to vRA for this catalog request. TYPE must be "string" or "integer". ' \
            "Can be used multiple times.",
          default:     {},
          proc:        proc { |param|
            Chef::Config[:knife][:vra_extra_params] ||= {}
            key, value_str = param.split("=")
            Chef::Config[:knife][:vra_extra_params].merge!(key => value_str)
          }

        def validate_params!
          super

          if @name_args.empty?
            ui.error("You must supply a Catalog ID to use for your new server.")
            exit 1
          end

          check_for_missing_config_values!(:cpus, :memory, :requested_for)

          validate_extra_params!
        end

        def before_exec_command
          super

          @create_options = {
            catalog_id: @name_args.first,
            cpus: config[:cpus],
            memory: config[:memory],
            requested_for: config[:requested_for],
            subtenant_id: config[:subtenant_id],
            lease_days: config[:lease_days],
            notes: config[:notes],
            extra_params: extra_params,
            wait_time: config[:server_create_timeout],
            refresh_rate: config[:request_refresh_rate],
          }
        end

        def before_bootstrap
          super

          config[:chef_node_name] = config[:chef_node_name] ? config[:chef_node_name] : server.name
          config[:bootstrap_ip_address] = hostname_for_server
        end

        def extra_params
          return if Chef::Config[:knife][:vra_extra_params].nil? || Chef::Config[:knife][:vra_extra_params].empty?

          Chef::Config[:knife][:vra_extra_params].each_with_object([]) do |(key, value_str), memo|
            type, value = value_str.split(":")
            memo << { key: key, type: type, value: value }
          end
        end

        def validate_extra_params!
          return if extra_params.nil?

          extra_params.each do |param|
            raise ArgumentError, "No type and value set for extra parameter #{param[:key]}" if param[:type].nil? || param[:value].nil?
            raise ArgumentError, "Invalid parameter type for #{param[:key]} - must be string or integer" unless
              param[:type] == "string" || param[:type] == "integer"
          end
        end

        def hostname_for_server
          ip_address = server.ip_addresses.first

          ip_address.nil? ? server.name : ip_address
        end
      end
    end
  end
end
