require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "yaml"
require "httparty"
require "json"
require_relative "../helper/ddg_apple_automation_helper"

module Fastlane
  module Actions
    class MattermostSendMessageAction < Action
      def self.run(params)
        github_handle = params[:github_handle]
        template_name = params[:template_name]
        mm_webhook_url = params[:mattermost_webhook_url]
        args = (params[:template_args] || {}).merge(Hash(ENV).transform_keys { |key| key.downcase.gsub('-', '_') })
        mapping_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("mattermost_send_message/github-mattermost-user-id-mapping.yml")
        user_mapping = YAML.load_file(mapping_file)
        mattermost_user_handle = user_mapping[github_handle]

        if mattermost_user_handle.nil? || mattermost_user_handle.to_s.empty?
          UI.message("Mattermost user handle not known for #{github_handle}, skipping sending message")
          return
        end

        text = process_yaml_template(template_name, args)
        payload = {
          "channel" => mattermost_user_handle,
          "username" => "GitHub Actions",
          "text" => text,
          "icon_url" => "https://duckduckgo.com/assets/logo_header.v108.svg"
        }

        response = HTTParty.post(mm_webhook_url, {
          headers: { 'Content-Type' => 'application/json' },
          body: payload.to_json
        })

        # Check response status
        if response.success?
          UI.success("Message sent successfully!")
        else
          UI.user_error!("Failed to send message: #{response.body}")
        end
      end

      def self.description
        "This action sends a message to Mattermost, reporting the outcome to the user who triggered the workflow"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        # Optional:
        ""
      end

      def self.process_yaml_template(template_name, args)
        template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("mattermost_send_message/templates/#{template_name}.yml.erb")
        yaml = Helper::DdgAppleAutomationHelper.process_erb_template(template_file, args)
        data = YAML.safe_load(yaml)
        return data["text"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :mattermost_webhook_url,
                                       env_name: "MM_WEBHOOK_URL",
                                       description: "Mattermost webhook URL",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :template_name,
                                       description: "Name of a template file (without extension) for the message. Templates can be found in assets/mattermost_send_message/templates subdirectory.
      The file is processed before being posted",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
