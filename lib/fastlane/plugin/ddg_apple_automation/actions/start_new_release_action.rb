require "fastlane/action"
require "fastlane_core/configuration/config_item"
require_relative "../helper/asana_helper"
require_relative "../helper/git_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class StartNewReleaseAction < Action
      def self.run(params)
        Helper::GitHelper.setup_git_user

        # macos_codefreeze_prechecks
        # new_version = validate_new_version(options)
        # macos_create_release_branch(version: new_version)
        # macos_update_embedded_files
        # macos_update_version_config(version: new_version)
        # sh('git', 'push')
        # sh("echo \"release_branch_name=#{RELEASE_BRANCH}/#{new_version}\" >> $GITHUB_OUTPUT") if is_ci

        # - name: Get Asana user ID
        #   id: get-asana-user-id
        #   shell: bash
        #   run: bundle exec fastlane run asana_get_user_id_for_github_handle github_handle:"${{ github.actor }}"

        # - name: Create release task
        #   id: create_release_task
        #   env:
        #     ASANA_ACCESS_TOKEN: ${{ secrets.ASANA_ACCESS_TOKEN }}
        #     ASSIGNEE_ID: ${{ steps.get-asana-user-id.outputs.asana_user_id }}
        #   run: |
        #     version="$(echo ${{ steps.make_release_branch.outputs.release_branch_name }} | cut -d '/' -f 2)"
        #     task_name="macOS App Release $version"
        #     asana_task_id="$(curl -fLSs -X POST "https://app.asana.com/api/1.0/task_templates/${{ vars.MACOS_RELEASE_TASK_TEMPLATE_ID }}/instantiateTask" \
        #       -H "Authorization: Bearer ${{ env.ASANA_ACCESS_TOKEN }}" \
        #       -H "Content-Type: application/json" \
        #       -d "{ \"data\": { \"name\": \"$task_name\" }}" \
        #       | jq -r .data.new_task.gid)"
        #     echo "marketing_version=${version}" >> $GITHUB_OUTPUT
        #     echo "asana_task_id=${asana_task_id}" >> $GITHUB_OUTPUT
        #     echo "asana_task_url=https://app.asana.com/0/0/${asana_task_id}/f" >> $GITHUB_OUTPUT

        #     curl -fLSs -X POST "https://app.asana.com/api/1.0/sections/${{ vars.MACOS_APP_DEVELOPMENT_RELEASE_SECTION_ID }}/addTask" \
        #       -H "Authorization: Bearer ${{ env.ASANA_ACCESS_TOKEN }}" \
        #       -H "Content-Type: application/json" \
        #       --output /dev/null \
        #       -d "{\"data\": {\"task\": \"${asana_task_id}\"}}"

        #     curl -fLSs -X PUT "https://app.asana.com/api/1.0/tasks/${asana_task_id}" \
        #       -H "Authorization: Bearer ${{ env.ASANA_ACCESS_TOKEN }}" \
        #       -H "Content-Type: application/json" \
        #       --output /dev/null \
        #       -d "{ \"data\": { \"assignee\": \"$ASSIGNEE_ID\" }}"

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
          FastlaneCore::ConfigItem.new(key: :release_task_template_id,
                                       description: "Release task template ID",
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
