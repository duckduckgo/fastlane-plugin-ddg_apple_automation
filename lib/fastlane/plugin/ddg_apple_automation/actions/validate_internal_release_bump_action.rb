require "fastlane/action"
require "fastlane_core/configuration/config_item"
require_relative "asana_find_release_task_action"
require_relative "asana_add_comment_action"
require_relative "../helper/asana_helper"
require_relative "../helper/git_helper"

module Fastlane
  module Actions
    class ValidateInternalReleaseBumpAction < Action
      def self.run(params)
        Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        options = params.values
        find_release_task_if_needed(options)

        Helper::GitHelper.assert_release_branch_is_not_frozen(options[:release_branch], params[:platform], options[:github_token])

        if params[:is_scheduled_release] && !Helper::GitHelper.assert_branch_has_changes(options[:release_branch], params[:platform])
          UI.important("No changes to the release branch (or only changes to scripts and workflows). Skipping automatic release.")
          Helper::GitHubActionsHelper.set_output("skip_release", true)
          return
        end

        UI.important("New code changes found in the release branch since the last release. Will bump internal release now.")

        UI.message("Validating release notes")
        release_notes = Helper::AsanaHelper.fetch_release_notes(options[:release_task_id], options[:asana_access_token], output_type: "raw")
        if release_notes.empty? || release_notes.include?("<-- Add release notes here -->")
          UI.user_error!("Release notes are empty or contain a placeholder. Please add release notes to the Asana task and restart the workflow.")
        else
          UI.message("Release notes are valid: #{release_notes}")
        end
      end

      def self.find_release_task_if_needed(params)
        if params[:release_task_url].to_s.empty?
          params.merge!(
            Fastlane::Actions::AsanaFindReleaseTaskAction.run(
              asana_access_token: params[:asana_access_token],
              github_token: params[:github_token],
              platform: params[:platform]
            )
          )
        else
          params[:release_task_id] = Helper::AsanaHelper.extract_asana_task_id(params[:release_task_url], set_gha_output: false)
          other_action.ensure_git_branch(branch: "^release/.+$")
          params[:release_branch] = other_action.git_branch

          Helper::GitHubActionsHelper.set_output("release_branch", params[:release_branch])
          Helper::GitHubActionsHelper.set_output("release_task_id", params[:release_task_id])
          Helper::GitHubActionsHelper.set_output("release_task_url", params[:release_task_url])
        end
      end

      def self.description
        "Performs checks to decide if a subsequent internal release should be made"
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
* finds the git branch and Asana task for the current internal release,
* checks for changes to the release branch,
* ensures that release notes aren't empty or placeholder.
        DETAILS
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.is_scheduled_release,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :release_task_url,
                                       description: "Asana release task URL",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
