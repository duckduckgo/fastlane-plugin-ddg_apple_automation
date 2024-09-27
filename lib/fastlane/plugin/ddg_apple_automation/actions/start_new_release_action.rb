require "fastlane/action"
require "fastlane_core/configuration/config_item"
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

        release_branch_name, new_version = create_release_branch(options)
        options[:version] = new_version
        options[:release_branch_name] = release_branch_name

        Helper::AsanaHelper.create_release_task(options[:platform], options[:version], options[:asana_user_id], options[:asana_access_token])

        update_asana_tasks_for_release(options)
      end

      def self.update_asana_tasks_for_release(params)
        # - name: Update Asana tasks for the release
        #   env:
        #     ASANA_ACCESS_TOKEN: ${{ secrets.ASANA_ACCESS_TOKEN }}
        #     GH_TOKEN: ${{ github.token }}
        #   run: |
        #     ./scripts/update_asana_for_release.sh \
        #       internal \
        #       ${{ steps.create_release_task.outputs.asana_task_id }} \
        #       ${{ vars.MACOS_APP_BOARD_VALIDATION_SECTION_ID }} \
        #       ${{ steps.create_release_task.outputs.marketing_version }}
      end

      def self.create_release_branch(params)
        Helper::DdgAppleAutomationHelper.code_freeze_prechecks(other_action) unless Helper.is_ci?
        new_version = Helper::DdgAppleAutomationHelper.validate_new_version(params[:version])
        create_release_branch(new_version)
        update_embedded_files(params, other_action)
        update_version_config(new_version)
        other_action.push_to_git_remote
        Helper::GitHubActionsHelper.set_output("release_branch_name", "#{Helper::DdgAppleAutomationHelper::RELEASE_BRANCH}/#{new_version}")

        return release_branch_name, new_version
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
        * creates a new Asana release task based off the provided task template.
        DETAILS
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version number to force (calculated automatically if not provided)",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :release_task_template_id,
                                       description: "Release task template ID",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
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
