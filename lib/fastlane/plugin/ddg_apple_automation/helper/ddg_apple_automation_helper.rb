require "fastlane_core/configuration/config_item"
require "fastlane_core/ui/ui"
require_relative "github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DdgAppleAutomationHelper
      ASANA_APP_URL = "https://app.asana.com/0/0"
      ASANA_TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}
      ERROR_ASANA_ACCESS_TOKEN_NOT_SET = "ASANA_ACCESS_TOKEN is not set"
      ERROR_GITHUB_TOKEN_NOT_SET = "GITHUB_TOKEN is not set"

      def self.asana_task_url(task_id)
        if task_id.to_s.empty?
          UI.user_error!("Task ID cannot be empty")
          return
        end
        "#{ASANA_APP_URL}/#{task_id}/f"
      end

      def self.extract_asana_task_id(task_url)
        if (match = task_url.match(ASANA_TASK_URL_REGEX))
          task_id = match[1]
          Helper::GitHubActionsHelper.set_output("asana_task_id", task_id)
          task_id
        else
          UI.user_error!("URL has incorrect format (attempted to match #{ASANA_TASK_URL_REGEX})")
        end
      end

      def self.path_for_asset_file(file)
        File.expand_path("../assets/#{file}", __dir__)
      end

      def self.load_file(file)
        File.read(file)
      rescue StandardError
        UI.user_error!("Error: The file '#{file}' does not exist.")
      end

      def self.sanitize_asana_html_notes(content)
        content.gsub(/\s+/, ' ')                           # replace multiple whitespaces with a single space
               .gsub(/>\s+</, '><')                        # remove spaces between HTML tags
               .strip                                      # remove leading and trailing whitespaces
               .gsub(%r{<br\s*/?>}, "\n")                  # replace <br> tags with newlines
      end

      def self.sanitize_html_and_replace_env_vars(content)
        content.gsub(/\$\{(\w+)\}/) { ENV.fetch($1, '') }  # replace environment variables
               .gsub(/\s+/, ' ')                           # replace multiple whitespaces with a single space
               .gsub(/>\s+</, '><')                        # remove spaces between HTML tags
               .strip                                      # remove leading and trailing whitespaces
               .gsub(%r{<br\s*/?>}, "\n")                  # replace <br> tags with newlines
      end
    end
  end
end

module FastlaneCore
  class ConfigItem
    def self.asana_access_token
      FastlaneCore::ConfigItem.new(key: :asana_access_token,
                                   env_name: "ASANA_ACCESS_TOKEN",
                                   description: "Asana access token",
                                   optional: false,
                                   sensitive: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!(Fastlane::Helper::DdgAppleAutomationHelper::ERROR_ASANA_ACCESS_TOKEN_NOT_SET) if value.to_s.length == 0
                                   end)
    end

    def self.github_token
      FastlaneCore::ConfigItem.new(key: :github_token,
                                   env_name: "GITHUB_TOKEN",
                                   description: "GitHub token",
                                   optional: false,
                                   sensitive: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!(Fastlane::Helper::DdgAppleAutomationHelper::ERROR_GITHUB_TOKEN_NOT_SET) if value.to_s.length == 0
                                   end)
    end
  end
end
