require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "asana_create_action_item_action"
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

        if options[:release_type] == 'internal'
          options[:version] = Helper::DdgAppleAutomationHelper.current_version(params[:platform])
          Helper::AsanaHelper.update_asana_tasks_for_internal_release(options)
        else
          options[:version] = Helper::DdgAppleAutomationHelper.extract_version_from_tag(params[:platform], options[:tag])
          announcement_task_html_notes = Helper::AsanaHelper.update_asana_tasks_for_public_release(options)
          Fastlane::Actions::AsanaCreateActionItemAction.run(
            asana_access_token: options[:asana_access_token],
            task_url: Helper::AsanaHelper.asana_task_url(options[:release_task_id]),
            task_name: "Announce the release to the company",
            html_notes: announcement_task_html_notes,
            github_handle: options[:github_handle],
            is_scheduled_release: options[:is_scheduled_release]
          )
        end
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
          FastlaneCore::ConfigItem.is_scheduled_release,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :tag,
                                       description: "Tagged version from Git releases - format <app-version>-<build-number>",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle - required when release_type is 'public'",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :release_task_id,
                                       description: "Asana release task ID",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :release_type,
                                       description: "Release type - 'internal' or 'public' (use 'public' for hotfixes)",
                                       optional: true,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("release_type must be equal to 'internal' or 'public'") unless ['internal', 'public'].include?(value.to_s)
                                       end),
          FastlaneCore::ConfigItem.new(key: :target_section_id,
                                       description: "Section ID in Asana where tasks included in the release should be moved",
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
