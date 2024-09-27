require "fastlane_core/ui/ui"
require "asana"
require "httparty"
require_relative "ddg_apple_automation_helper"
require_relative "github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AsanaHelper
      ASANA_API_URL = "https://app.asana.com/api/1.0"
      ASANA_APP_URL = "https://app.asana.com/0/0"
      ASANA_TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}
      ERROR_ASANA_ACCESS_TOKEN_NOT_SET = "ASANA_ACCESS_TOKEN is not set"

      IOS_HOTFIX_TASK_TEMPLATE_ID = "1205352950253153"
      IOS_RELEASE_TASK_TEMPLATE_ID = "1205355281110338"
      MACOS_HOTFIX_TASK_TEMPLATE_ID = "1206724592377782"
      MACOS_RELEASE_TASK_TEMPLATE_ID = "1206127427850447"

      IOS_APP_DEVELOPMENT_RELEASE_SECTION_ID = "1138897754570756"
      MACOS_APP_DEVELOPMENT_RELEASE_SECTION_ID = "1202202395298964"

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
          c.default_headers("Asana-Enable" => "new_goal_memberships,new_user_task_lists")
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
          c.default_headers("Asana-Enable" => "new_goal_memberships,new_user_task_lists")
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
          c.default_headers("Asana-Enable" => "new_goal_memberships,new_user_task_lists")
        end

        begin
          asana_client.tasks.find_by_id(task_id).attach(filename: file_path, mime: "application/octet-stream")
        rescue StandardError => e
          UI.user_error!("Failed to upload file to Asana task: #{e}")
          return
        end
      end

      def self.release_template_task_id(platform, is_hotfix: false)
        case platform
        when "ios"
          is_hotfix ? IOS_HOTFIX_TASK_TEMPLATE_ID : IOS_RELEASE_TASK_TEMPLATE_ID
        when "macos"
          is_hotfix ? MACOS_HOTFIX_TASK_TEMPLATE_ID : MACOS_RELEASE_TASK_TEMPLATE_ID
        else
          UI.user_error!("Unsupported platform: #{platform}")
        end
      end

      def self.release_task_name(version, platform, is_hotfix: false)
        case platform
        when "ios"
          is_hotfix ? "iOS App Release #{version}" : "iOS App Hotfix Release #{version}"
        when "macos"
          is_hotfix ? "macOS App Release #{version}" : "macOS App Hotfix Release #{version}"
        else
          UI.user_error!("Unsupported platform: #{platform}")
        end
      end

      def self.release_section_id(platform)
        case platform
        when "ios"
          IOS_APP_DEVELOPMENT_RELEASE_SECTION_ID
        when "macos"
          MACOS_APP_DEVELOPMENT_RELEASE_SECTION_ID
        else
          UI.user_error!("Unsupported platform: #{platform}")
        end
      end

      def self.create_release_task(platform, version, assignee_id, asana_access_token)
        template_task_id = release_template_task_id(platform)
        task_name = release_task_name(version, platform)
        section_id = release_section_id(platform)

        # task_templates is unavailable in the Asana client so we need to use the API directly
        url = ASANA_API_URL + "/task_templates/#{template_task_id}/instantiateTask"
        response = HTTParty.post(
          url,
          headers: { 'Authorization' => "Bearer #{asana_access_token}", 'Content-Type' => 'application/json' },
          body: { data: { name: "[TEST] #{task_name}" } }
        )

        if response.success?
          task_id = response.parsed_response.dig('data', 'new_task', 'gid')
          task_url = asana_task_url(task_id)
          Helper::GitHubActionsHelper.set_output("asana_task_id", task_id)
          Helper::GitHubActionsHelper.set_output("asana_task_url", task_url)
        else
          UI.user_error!("Failed to instantiate task from template #{template_task_id}: (#{response.code} #{response.message})")
        end

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
          c.default_headers("Asana-Enable" => "new_goal_memberships,new_user_task_lists")
        end

        asana_client.sections.add_task_for_section(section_gid: section_id, task_gid: task_id)
        asana_client.tasks.update_task(task_gid: task_id, data: { assignee: assignee_id })
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
