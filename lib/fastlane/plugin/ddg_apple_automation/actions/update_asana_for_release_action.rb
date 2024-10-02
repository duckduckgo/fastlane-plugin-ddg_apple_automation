require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class UpdateAsanaForReleaseAction < Action
      def self.run(params)
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        options = params.values
        options[:version] = Helper::DdgAppleAutomationHelper.current_version
        Helper::AsanaHelper.update_asana_tasks_for_release(options)
      end

      def self.description
        "Processes tasks included in the release and the Asana release task"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        <<-DETAILS
This action performs the following tasks:
* moves tasks included in the release to Validation section,
* updates Asana release task description with tasks included in the release.
        DETAILS
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :release_task_id,
                                       description: "Asana release task ID",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :validation_section_id,
                                       description: "Validation section ID",
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
