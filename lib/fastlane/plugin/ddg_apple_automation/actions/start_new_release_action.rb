require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class StartNewReleaseAction < Action
      def self.run(params)
        Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        options = params.values
        options[:asana_user_id] = Helper::AsanaHelper.get_asana_user_id_for_github_handle(options[:github_handle])

        if params[:is_hotfix]
          release_branch_name, new_version = Helper::DdgAppleAutomationHelper.prepare_hotfix_branch(
            params[:github_token], params[:platform], other_action, options
          )
        else
          release_branch_name, new_version = Helper::DdgAppleAutomationHelper.prepare_release_branch(
            params[:platform], params[:version], other_action
          )
        end

        options[:version] = new_version
        options[:release_branch_name] = release_branch_name

        release_task_id = Helper::AsanaHelper.create_release_task(options[:platform], options[:version], options[:asana_user_id], options[:asana_access_token], is_hotfix: options[:is_hotfix])
        options[:release_task_id] = release_task_id

        # Helper::AsanaHelper.update_asana_tasks_for_internal_release(options) unless params[:is_hotfix]
      end

      def self.description
        "Starts a new release"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The newly created release task ID"
      end

      def self.details
        <<-DETAILS
This action performs the following tasks:
* creates a new release branch,
* updates version and build number,
* updates embedded files,
* pushes the changes to the remote repository,
* creates a new Asana release task based off the provided task template,
* updates the Asana release task with tasks included in the release.
For hotfix releases, the action creates a hotfix branch off the latest public release tag, updates the build number and pushes the changes.
        DETAILS
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version number to force (calculated automatically if not provided)",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :target_section_id,
                                       description: "Section ID in Asana where tasks included in the release should be moved",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :is_hotfix,
                                       description: "Is this a hotfix release?",
                                       optional: true,
                                       type: Boolean,
                                       default_value: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
