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
      @constants = {}

      def self.setup_constants(platform)
        case platform
        when "ios"
          @constants = {
            repo_name: "duckduckgo/ios",
            release_tag_prefix: "ios-app-release-"
          }
        when "macos"
          @constants = {
            repo_name: "duckduckgo/macos-browser",
            release_tag_prefix: "macos-app-release-"
          }
        end
      end

      def self.run(params)
        Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        setup_constants(params[:platform])

        options = params.values
        options[:asana_user_id] = Helper::AsanaHelper.get_asana_user_id_for_github_handle(options[:github_handle])

        release_branch_name, new_version = Helper::DdgAppleAutomationHelper.prepare_release_branch(
          params[:platform], params[:version], other_action
        )
        options[:version] = new_version
        options[:release_branch_name] = release_branch_name

        release_task_id = Helper::AsanaHelper.create_release_task(options[:platform], options[:version], options[:asana_user_id], options[:asana_access_token])
        options[:release_task_id] = release_task_id

        update_asana_tasks_for_release(options)
      end

      def self.update_asana_tasks_for_release(params)
        UI.message("Checking latest public release in GitHub")
        client = Octokit::Client.new(access_token: params[:github_token])
        latest_public_release = client.latest_release(@constants[:repo_name])
        UI.success("Latest public release: #{latest_public_release.tag_name}")

        UI.message("Extracting task IDs from git log since #{latest_public_release.tag_name} release")
        task_ids = Helper::AsanaHelper.get_task_ids_from_git_log(latest_public_release.tag_name)
        UI.success("#{task_ids.count} task(s) found.")

        UI.message("Fetching release notes from Asana release task (#{Helper::AsanaHelper.asana_task_url(params[:release_task_id])})")
        release_notes = Helper::AsanaHelper.fetch_release_notes(params[:release_task_id], params[:asana_access_token])
        UI.success("Release notes: #{release_notes}")

        UI.message("Generating release task description using fetched release notes and task IDs")
        html_notes = Helper::ReleaseTaskHelper.construct_release_task_description(release_notes, task_ids)

        UI.message("Updating release task")
        asana_client = Helper::AsanaHelper.make_asana_client(params[:asana_access_token])
        asana_client.tasks.update_task(task_gid: params[:release_task_id], html_notes: html_notes)
        UI.success("Release task content updated: #{Helper::AsanaHelper.asana_task_url(params[:release_task_id])}")

        task_ids.append(params[:release_task_id])

        UI.message("Moving tasks to Validation section")
        Helper::AsanaHelper.move_tasks_to_section(task_ids, params[:validation_section_id], params[:asana_access_token])
        UI.success("All tasks moved to Validation section")

        tag_name = "#{@constants[:release_tag_prefix]}#{params[:version]}"
        UI.message("Fetching or creating #{tag_name} Asana tag")
        tag_id = Helper::AsanaHelper.find_or_create_asana_release_tag(tag_name, params[:release_task_id], params[:asana_access_token])
        UI.success("#{tag_name} tag URL: #{Helper::AsanaHelper.asana_tag_url(tag_id)}")

        UI.message("Tagging tasks with #{tag_name} tag")
        Helper::AsanaHelper.tag_tasks(tag_id, task_ids, params[:asana_access_token])
        UI.success("All tasks tagged with #{tag_name} tag")
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
