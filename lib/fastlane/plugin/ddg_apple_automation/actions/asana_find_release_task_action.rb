require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require "octokit"
require "time"
require_relative "asana_add_comment_action"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaFindReleaseTaskAction < Action
      @constants = {}

      def self.setup_constants(platform)
        case platform
        when "ios"
          @constants = {
            release_task_prefix: "iOS App Release",
            hotfix_task_prefix: "iOS App Hotfix Release",
            release_section_id: "1138897754570756"
          }
        when "macos"
          @constants = {
            release_task_prefix: "macOS App Release",
            hotfix_task_prefix: "macOS App Hotfix Release",
            release_section_id: "1202202395298964"
          }
        end
      end

      def self.run(params)
        asana_access_token = params[:asana_access_token]
        github_token = params[:github_token]
        platform = params[:platform] || Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        setup_constants(platform)

        UI.message("Checking latest marketing version")
        latest_marketing_version = find_latest_marketing_version(github_token, params[:platform])
        UI.success("Latest marketing version: #{latest_marketing_version}")
        UI.message("Searching for release task for version #{latest_marketing_version}")
        release_task_id, hotfix_task_id = find_release_task(latest_marketing_version, asana_access_token)
        UI.user_error!("No release task found for version #{latest_marketing_version}") unless release_task_id

        release_task_url = Helper::AsanaHelper.asana_task_url(release_task_id)
        release_branch = Helper::DdgAppleAutomationHelper.release_branch_name(platform, latest_marketing_version)
        UI.success("Found #{latest_marketing_version} release task: #{release_task_url}")

        report_hotfix_task_if_needed(hotfix_task_id, release_task_id, asana_access_token)

        Helper::GitHubActionsHelper.set_output("release_branch", release_branch)
        Helper::GitHubActionsHelper.set_output("release_task_id", release_task_id)
        Helper::GitHubActionsHelper.set_output("release_task_url", release_task_url)

        {
          release_task_id: release_task_id,
          release_task_url: release_task_url,
          release_branch: release_branch
        }
      end

      def self.find_latest_marketing_version(github_token, platform)
        latest_internal_release = Helper::GitHelper.latest_release(Helper::GitHelper.repo_name, true, platform, github_token)

        version = extract_version_from_tag_name(latest_internal_release&.tag_name)
        if version.to_s.empty?
          Fastlane::UI.user_error!("Failed to find latest marketing version")
          return
        end
        unless self.validate_semver(version)
          Fastlane::UI.user_error!("Invalid marketing version: #{version}, expected format: MAJOR.MINOR.PATCH")
          return
        end
        version
      end

      def self.extract_version_from_tag_name(tag_name)
        # Remove build number (if present) and platform suffix from the tag name
        tag_name&.split(/[-+]/)&.first
      end

      def self.validate_semver(version)
        # we only need basic "x.y.z" validation here
        version.match?(/\A\d+\.\d+\.\d+\z/)
      end

      def self.find_release_task(version, asana_access_token)
        asana_client = Helper::AsanaHelper.make_asana_client(asana_access_token)
        release_task_id = nil
        hotfix_task_id = nil

        begin
          tasks = asana_client.tasks.find_all(
            section: @constants[:release_section_id],
            per_page: 100,
            completed_since: 'now', # return only incomplete tasks
            options: { fields: ['name', 'created_at'] }
          )

          # Go through all tasks in the section (there may be multiple requests in case
          # there are more than 100 tasks in the section).
          # Repeat until no more pages are left (next_page.uri is null).
          loop do
            hotfix_task_id ||= find_hotfix_task_in_response(tasks)
            release_task_id ||= find_release_task_in_response(tasks, version)

            tasks = tasks.next_page
            # Don't return as soon as release task is found, as we want to ensure there's no hotfix task
            break if tasks.nil?
          end
        rescue StandardError => e
          UI.user_error!("Failed to fetch release task: #{e}")
        end

        [release_task_id, hotfix_task_id]
      end

      def self.find_release_task_in_response(tasks, version)
        release_task_name = "#{@constants[:release_task_prefix]} #{version}"
        release_task = tasks.find { |task| task.name == release_task_name }
        release_task_id = release_task&.gid
        created_at = release_task&.created_at

        ensure_task_not_too_old(release_task_id, created_at)
        release_task_id
      end

      # Only consider release tasks created in the last 5 days.
      # - We don't want to bump internal release automatically for release tasks that are open for more than a week.
      # - The automatic check is only done Tuesday-Friday. If the release task is still open next Tuesday, it's unexpected,
      #   and likely something went wrong.
      def self.ensure_task_not_too_old(release_task_id, created_at)
        if created_at
          created_at_timestamp = Time.parse(created_at).to_i
          five_days_ago = Time.now.to_i - (5 * 24 * 60 * 60)
          if created_at_timestamp <= five_days_ago
            UI.user_error!("Found release task: #{release_task_id} but it's older than 5 days, skipping.")
            return
          end
        end
      end

      def self.find_hotfix_task_in_response(tasks)
        tasks.find { |task| task.name.start_with?(@constants[:hotfix_task_prefix]) }&.gid
      end

      def self.report_hotfix_task_if_needed(hotfix_task_id, release_task_id, asana_access_token)
        return unless hotfix_task_id

        hotfix_task_url = Helper::AsanaHelper.asana_task_url(hotfix_task_id)
        hotfix_task_assignee_id = Helper::AsanaHelper.extract_asana_task_assignee(hotfix_task_id, asana_access_token)
        release_task_assignee_id = Helper::AsanaHelper.extract_asana_task_assignee(release_task_id, asana_access_token)

        begin
          UI.important("Adding user #{release_task_assignee_id} as collaborator on hotfix release task #{hotfix_task_id}")
          asana_client.tasks.add_followers_for_task(task_gid: hotfix_task_id, followers: [release_task_assignee_id])
        rescue StandardError => e
          Helper::DdgAppleAutomationHelper.log_error(e)
          UI.user_error!("Failed to add user #{release_task_assignee_id} as collaborator on task #{hotfix_task_id}")
          return
        end

        AsanaAddCommentAction.run(
          task_id: hotfix_task_id,
          template_name: 'hotfix-preventing-release-bump',
          template_args: {
            hotfix_task_assignee_id: hotfix_task_assignee_id,
            release_task_assignee_id: release_task_assignee_id,
            release_task_id: release_task_id
          },
          asana_access_token: asana_access_token
        )
        UI.user_error!("Found active hotfix task: #{hotfix_task_url}")
        return
      end

      def self.description
        "Finds an active release task in Asana"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The hash containing release task ID, task URL and release branch name"
      end

      def self.details
        "This action searches macOS App Development or iOS App Development Asana project for an active release task
        matching the latest version (as specified by GitHub releases). Returns an error when no release task is found,
        or when there's an active (incomplete) hotfix release task. Tasks are identified by the name."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.platform
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
