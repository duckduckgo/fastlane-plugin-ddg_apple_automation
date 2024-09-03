require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "httparty"
require "json"
require "octokit"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaFindReleaseTaskAction < Action
      @constants = {}

      def self.setup_constants(platform)
        case platform
        when "ios"
          @constants = {
            repo_name: "duckduckgo/ios",
            release_task_prefix: "iOS App Release",
            hotfix_task_prefix: "iOS App Hotfix Release",
            release_section_id: "1138897754570756"
          }
        when "macos"
          @constants = {
            repo_name: "duckduckgo/macos-browser",
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

        latest_marketing_version = find_latest_marketing_version(github_token)
        release_task_id = find_release_task(latest_marketing_version, platform, asana_access_token)

        release_task_url = "#{Helper::DdgAppleAutomationHelper::ASANA_APP_URL}/#{release_task_id}/f"
        UI.success("Found #{latest_marketing_version} release task: #{release_task_url}")

        Helper::GitHubActionsHelper.set_output("release_branch", "release/#{latest_marketing_version}")
        Helper::GitHubActionsHelper.set_output("release_task_id", release_task_id)
        Helper::GitHubActionsHelper.set_output("release_task_url", release_task_url)

        {
          release_task_id: release_task_id,
          release_task_url: release_task_url,
          release_branch: "release/#{latest_marketing_version}"
        }
      end

      def self.find_latest_marketing_version(github_token)
        client = Octokit::Client.new(access_token: github_token)

        # NOTE: `client.latest_release` returns release marked as "latest", i.e. a public release
        latest_internal_release = client.releases(@constants[:repo_name], { per_page: 1 }).first
        tag_name = latest_internal_release['tag_name']
        version = tag_name&.split("-")&.first
        Fastlane::UI.user_error!("Failed to fetch latest release") if version.nil?
        version
      end

      def self.find_release_task(version, platform, asana_access_token)
        release_task_name = "#{@constants[:release_task_prefix]} #{version}"
        # `completed_since=now` returns only incomplete tasks
        url = Helper::DdgAppleAutomationHelper::ASANA_API_URL + "/sections/#{@constants[:release_section_id]}/tasks?opt_fields=name,created_at&limit=100&completed_since=now"

        release_task_id = nil

        # Go through all tasks in the section (there may be multiple requests in case
        # there are more than 100 tasks in the section).
        # Repeat until no more pages are left (next_page.uri is null).
        loop do
          response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{asana_access_token}" })

          find_hotfix_task_in_response(response)
          release_task_id ||= find_release_task_in_response(response, release_task_name)

          url = response.dig('next_page', 'uri')

          # Don't return as soon as release task is found, as we want to ensure there's no hotfix task
          break if url.nil?
        end

        release_task_id
      end

      def self.find_release_task_in_response(response, release_task_name)
        release_task = response['data']&.find { |task| task['name'] == release_task_name }
        release_task_id = release_task&.dig('gid')
        created_at = release_task&.dig('created_at')

        ensure_task_not_too_old(release_task_id, created_at)
        release_task_id
      end

      def self.find_hotfix_task_in_response(response)
        hotfix_task_id = response['data']
                         &.find { |task| task['name']&.start_with?(@constants[:hotfix_task_prefix]) }
                         &.dig('gid')

        if hotfix_task_id
          UI.user_error!("Found active hotfix task: #{Helper::DdgAppleAutomationHelper::ASANA_API_URL}/#{hotfix_task_id}")
          return
        end
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
          FastlaneCore::ConfigItem.new(key: :platform,
                                       description: "Platform (iOS or macOS) - optionally to override lane context value",
                                       optional: true,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("platform must be equal to 'ios' or 'macos'") unless ['ios', 'macos'].include?(value.to_s)
                                       end)

        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
