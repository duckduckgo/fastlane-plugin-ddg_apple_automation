require "fastlane_core/ui/ui"
require "asana"
require "httparty"
require "octokit"
require_relative "ddg_apple_automation_helper"
require_relative "git_helper"
require_relative "github_actions_helper"
require_relative "release_task_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AsanaHelper
      ASANA_API_URL = "https://app.asana.com/api/1.0"
      ASANA_TASK_URL_TEMPLATE = "https://app.asana.com/0/0/%s/f"
      ASANA_TAG_URL_TEMPLATE = "https://app.asana.com/0/%s/list"
      ASANA_TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}
      ASANA_WORKSPACE_ID = "137249556945"

      IOS_HOTFIX_TASK_TEMPLATE_ID = "1205352950253153"
      IOS_RELEASE_TASK_TEMPLATE_ID = "1205355281110338"
      MACOS_HOTFIX_TASK_TEMPLATE_ID = "1206724592377782"
      MACOS_RELEASE_TASK_TEMPLATE_ID = "1206127427850447"

      IOS_APP_DEVELOPMENT_RELEASE_SECTION_ID = "1138897754570756"
      MACOS_APP_DEVELOPMENT_RELEASE_SECTION_ID = "1202202395298964"

      def self.make_asana_client(asana_access_token)
        Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
          c.default_headers("Asana-Enable" => "new_goal_memberships,new_user_task_lists")
        end
      end

      def self.asana_task_url(task_id)
        if task_id.to_s.empty?
          UI.user_error!("Task ID cannot be empty")
          return
        end
        ASANA_TASK_URL_TEMPLATE % task_id
      end

      def self.asana_tag_url(tag_id)
        if tag_id.to_s.empty?
          UI.user_error!("Tag ID cannot be empty")
          return
        end
        ASANA_TAG_URL_TEMPLATE % tag_id
      end

      def self.extract_asana_task_id(task_url, set_gha_output: true)
        if (match = task_url.match(ASANA_TASK_URL_REGEX))
          task_id = match[1]
          if set_gha_output
            Helper::GitHubActionsHelper.set_output("asana_task_id", task_id)
          end
          task_id
        else
          UI.user_error!("URL has incorrect format (attempted to match #{ASANA_TASK_URL_REGEX})")
        end
      end

      def self.extract_asana_task_assignee(task_id, asana_access_token)
        client = make_asana_client(asana_access_token)

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

        asana_client = make_asana_client(asana_access_token)

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
        asana_client = make_asana_client(asana_access_token)

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
          is_hotfix ? "iOS App Hotfix Release #{version}" : "iOS App Release #{version}"
        when "macos"
          is_hotfix ? "macOS App Hotfix Release #{version}" : "macOS App Release #{version}"
        else
          UI.user_error!("Unsupported platform: #{platform}")
        end
      end

      def self.release_tag_name(version, platform)
        case platform
        when "ios"
          "ios-app-release-#{version}"
        when "macos"
          "macos-app-release-#{version}"
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

        UI.message("Creating release task for #{version}")
        # task_templates is unavailable in the Asana client so we need to use the API directly
        url = ASANA_API_URL + "/task_templates/#{template_task_id}/instantiateTask"
        response = HTTParty.post(
          url,
          headers: { 'Authorization' => "Bearer #{asana_access_token}", 'Content-Type' => 'application/json' },
          body: { data: { name: task_name } }.to_json
        )

        unless response.success?
          UI.user_error!("Failed to instantiate task from template #{template_task_id}: (#{response.code} #{response.message})")
          return
        end

        task_id = response.parsed_response.dig('data', 'new_task', 'gid')
        task_url = asana_task_url(task_id)
        Helper::GitHubActionsHelper.set_output("asana_task_id", task_id)
        Helper::GitHubActionsHelper.set_output("asana_task_url", task_url)
        UI.success("Release task for #{version} created at #{task_url}")

        asana_client = make_asana_client(asana_access_token)

        UI.message("Moving release task to section #{section_id}")
        asana_client.sections.add_task_for_section(section_gid: section_id, task: task_id)
        UI.message("Assigning release task to user #{assignee_id}")
        asana_client.tasks.update_task(task_gid: task_id, assignee: assignee_id)
        UI.success("Release task ready: #{task_url} ✅")

        task_id
      end

      # Updates asana tasks for a release
      #
      # @param github_token [String] GitHub token
      # @param asana_access_token [String] Asana access token
      # @param release_task_id [String] Asana access token
      # @param validation_section_id [String] ID of the 'Validation' section in the Asana project
      # @param version [String] version number
      #
      def self.update_asana_tasks_for_release(params)
        UI.message("Checking latest public release in GitHub")
        client = Octokit::Client.new(access_token: params[:github_token])
        latest_public_release = client.latest_release(Helper::GitHelper.repo_name(params[:platform]))
        UI.success("Latest public release: #{latest_public_release.tag_name}")

        UI.message("Extracting task IDs from git log since #{latest_public_release.tag_name} release")
        task_ids = get_task_ids_from_git_log(latest_public_release.tag_name)
        UI.success("#{task_ids.count} task(s) found.")

        UI.message("Fetching release notes from Asana release task (#{asana_task_url(params[:release_task_id])})")
        release_notes = fetch_release_notes(params[:release_task_id], params[:asana_access_token])
        UI.success("Release notes: #{release_notes}")

        UI.message("Generating release task description using fetched release notes and task IDs")
        html_notes = Helper::ReleaseTaskHelper.construct_release_task_description(release_notes, task_ids)

        UI.message("Updating release task")
        asana_client = make_asana_client(params[:asana_access_token])
        asana_client.tasks.update_task(task_gid: params[:release_task_id], html_notes: html_notes)
        UI.success("Release task content updated: #{asana_task_url(params[:release_task_id])}")

        task_ids.append(params[:release_task_id])

        UI.message("Moving tasks to Validation section")
        move_tasks_to_section(task_ids, params[:validation_section_id], params[:asana_access_token])
        UI.success("All tasks moved to Validation section")

        tag_name = release_tag_name(params[:version], params[:platform])
        UI.message("Fetching or creating #{tag_name} Asana tag")
        tag_id = find_or_create_asana_release_tag(tag_name, params[:release_task_id], params[:asana_access_token])
        UI.success("#{tag_name} tag URL: #{asana_tag_url(tag_id)}")

        UI.message("Tagging tasks with #{tag_name} tag")
        tag_tasks(tag_id, task_ids, params[:asana_access_token])
        UI.success("All tasks tagged with #{tag_name} tag")
      end

      def self.move_tasks_to_section(task_ids, section_id, asana_access_token)
        asana_client = make_asana_client(asana_access_token)

        task_ids.each_slice(10) do |batch|
          actions = batch.map do |task_id|
            {
              method: "post",
              relative_path: "/sections/#{section_id}/addTask",
              data: {
                task: task_id
              }
            }
          end
          UI.message("Moving tasks #{batch.join(', ')} to section #{section_id}")
          asana_client.batch_apis.create_batch_request(actions: actions)
        end
      end

      def self.find_or_create_asana_release_tag(tag_name, release_task_id, asana_access_token)
        asana_client = make_asana_client(asana_access_token)

        release_task_tags = asana_client.tasks.get_task(task_gid: release_task_id, options: { fields: ["tags"] }).tags

        if (tag_id = release_task_tags.find { |t| t.name == tag_name }&.gid) && !tag_id.to_s.empty?
          return tag_id
        end

        asana_client.tags.create_tag_for_workspace(workspace_gid: ASANA_WORKSPACE_ID, name: tag_name).gid
      end

      def self.tag_tasks(tag_id, task_ids, asana_access_token)
        asana_client = make_asana_client(asana_access_token)

        task_ids.each_slice(10) do |batch|
          actions = batch.map do |task_id|
            {
              method: "post",
              relative_path: "/tasks/#{task_id}/addTag",
              data: {
                tag: tag_id
              }
            }
          end
          UI.message("Tagging tasks #{batch.join(', ')}")
          asana_client.batch_apis.create_batch_request(actions: actions)
        end
      end

      def self.sanitize_asana_html_notes(content)
        content.gsub(/\s+/, ' ')                           # replace multiple whitespaces with a single space
               .gsub(/>\s+</, '><')                        # remove spaces between HTML tags
               .strip                                      # remove leading and trailing whitespaces
               .gsub(%r{<br\s*/?>}, "\n")                  # replace <br> tags with newlines
      end

      def self.get_task_ids_from_git_log(from_ref, to_ref = "HEAD")
        git_log = `git log #{from_ref}..#{to_ref}`

        git_log
          .gsub("\n", " ")
          .scan(%r{\bTask/Issue URL:.*?https://app\.asana\.com[/0-9f]+\b})
          .map { |task_line| task_line.gsub(/.*(https.*)/, '\1') }
          .map { |task_url| extract_asana_task_id(task_url, set_gha_output: false) }
      end

      def self.fetch_release_notes(release_task_id, asana_access_token, output_type: "asana")
        asana_client = make_asana_client(asana_access_token)

        release_task_body = asana_client.tasks.get_task(task_gid: release_task_id, options: { fields: ["notes"] }).notes

        ReleaseTaskHelper.extract_release_notes(release_task_body, output_type: output_type)
      end
    end
  end
end
