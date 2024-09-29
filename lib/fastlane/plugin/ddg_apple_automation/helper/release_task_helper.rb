require "fastlane_core/ui/ui"
require_relative "ddg_apple_automation_helper"
require_relative "github_actions_helper"
require_relative "release_notes/asana_release_notes_extractor"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class ReleaseTaskHelper
      def self.construct_release_task_description(release_notes, task_ids)
        template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("release_task_helper/templates/release_task_description.html.erb")
        Helper::DdgAppleAutomationHelper.process_erb_template(template_file, {
          release_notes: release_notes,
          task_ids: task_ids
        })
      end

      def self.extract_release_notes(task_body, output_type: "html")
        helper = AsanaReleaseNotesExtractor.new(output_type: "asana")
        helper.extract_release_notes(task_body)
      end
    end
  end
end
