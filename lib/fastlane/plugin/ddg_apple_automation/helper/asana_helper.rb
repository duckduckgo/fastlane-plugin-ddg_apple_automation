require "fastlane_core/ui/ui"
require "asana"
require_relative "ddg_apple_automation_helper"
require_relative "github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AsanaHelper
      ASANA_APP_URL = "https://app.asana.com/0/0"
      ASANA_TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}
      ERROR_ASANA_ACCESS_TOKEN_NOT_SET = "ASANA_ACCESS_TOKEN is not set"

      def self.asana_task_url(task_id)
        if task_id.to_s.empty?
          UI.user_error!("Task ID cannot be empty")
          return
        end
        "#{ASANA_APP_URL}/#{task_id}/f"
      end

      def self.extract_asana_task_id(task_url)
        if (match = task_url.match(ASANA_TASK_URL_REGEX))
          task_id = match[1]
          Helper::GitHubActionsHelper.set_output("asana_task_id", task_id)
          task_id
        else
          UI.user_error!("URL has incorrect format (attempted to match #{ASANA_TASK_URL_REGEX})")
        end
      end

      def self.extract_asana_task_assignee(task_id, asana_access_token)
        client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
          c.default_headers["Asana-Enable"] = "new_goal_memberships"
        end

        begin
          task = client.tasks.get_task(task_gid: task_id, options: { fields: ["assignee"] })
        rescue StandardError => e
          UI.user_error!("Failed to fetch task assignee: #{e}")
          return
        end

        assignee_id = task.assignee["gid"]
        Helper::GitHubActionsHelper.set_output("asana_assignee_id", assignee_id)
        assignee_id
      end

      def self.get_release_automation_subtask_id(task_url, asana_access_token)
        task_id = extract_asana_task_id(task_url)

        # Fetch release task assignee and set GHA output.
        # This is to match current GHA action behavior.
        # TODO: To be reworked for local execution.
        extract_asana_task_assignee(task_id, asana_access_token)

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
          c.default_headers["Asana-Enable"] = "new_goal_memberships"
        end

        begin
          subtasks = asana_client.tasks.get_subtasks_for_task(task_gid: task_id, options: { fields: ["name", "created_at"] })
        rescue StandardError => e
          UI.user_error!("Failed to fetch 'Automation' subtasks for task #{task_id}: #{e}")
          return
        end

        # Find oldest 'Automation' subtask
        automation_subtask_id = subtasks
                                .find_all { |task| task.name == 'Automation' }
                                &.min_by { |task| Time.parse(task.created_at) }
                                &.gid
        Helper::GitHubActionsHelper.set_output("asana_automation_task_id", automation_subtask_id)
        automation_subtask_id
      end

      def self.get_asana_user_id_for_github_handle(github_handle)
        mapping_file = File.expand_path('../assets/github-asana-user-id-mapping.yml', __dir__)
        user_mapping = YAML.load_file(mapping_file)
        asana_user_id = user_mapping[github_handle]

        if asana_user_id.nil? || asana_user_id.to_s.empty?
          UI.message("Asana User ID not found for GitHub handle: #{github_handle}")
        else
          Helper::GitHubActionsHelper.set_output("asana_user_id", asana_user_id)
          asana_user_id
        end
      end

      def self.upload_file_to_asana_task(task_id, file_path, asana_access_token)
        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
          c.default_headers["Asana-Enable"] = "new_goal_memberships"
        end

        begin
          asana_client.tasks.find_by_id(task_id).attach(filename: file_path, mime: "application/octet-stream")
        rescue StandardError => e
          UI.user_error!("Failed to upload file to Asana task: #{e}")
          return
        end
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
