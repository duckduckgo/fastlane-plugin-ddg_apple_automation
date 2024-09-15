require "fastlane_core/configuration/config_item"
require "fastlane_core/ui/ui"
require_relative "github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DdgAppleAutomationHelper
      ASANA_APP_URL = "https://app.asana.com/0/0"
      ASANA_TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}

      def self.process_erb_template(erb_file_path, args)
        template_content = load_file(erb_file_path)
        unless template_content
          UI.user_error!("Template file not found: #{erb_file_path}")
          return
        end

        erb_template = ERB.new(template_content)
        erb_template.result_with_hash(args)
      end

      def self.compute_tag(is_prerelease)
        version = File.read("Configuration/Version.xcconfig").chomp.split(" = ").last
        build_number = File.read("Configuration/BuildNumber.xcconfig").chomp.split(" = ").last
        if is_prerelease
          tag = "#{version}-#{build_number}"
        else
          tag = version
          promoted_tag = "#{version}-#{build_number}"
        end

        return tag, promoted_tag
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
                                     UI.user_error!("ASANA_ACCESS_TOKEN is not set") if value.to_s.length == 0
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
                                     UI.user_error!("GITHUB_TOKEN is not set") if value.to_s.length == 0
                                   end)
    end

    def self.platform
      FastlaneCore::ConfigItem.new(key: :platform,
                                   description: "Platform (iOS or macOS) - optionally to override lane context value",
                                   optional: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!("platform must be equal to 'ios' or 'macos'") unless ['ios', 'macos'].include?(value.to_s)
                                   end)
    end
  end
end
