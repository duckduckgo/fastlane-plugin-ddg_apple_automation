require "fastlane_core/configuration/config_item"
require "fastlane_core/ui/ui"
require "httparty"
require "rexml/document"
require "semantic"
require_relative "github_actions_helper"
require_relative "git_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class EmbeddedFilesHelper
      UPGRADABLE_EMBEDDED_FILES = {
          "ios" => Set.new([
                             'Core/AppPrivacyConfigurationDataProvider.swift',
                             'Core/AppTrackerDataSetProvider.swift',
                             'Core/ios-config.json',
                             'Core/trackerData.json'
                           ]),
          "macos" => Set.new([
                               'DuckDuckGo/ContentBlocker/AppPrivacyConfigurationDataProvider.swift',
                               'DuckDuckGo/ContentBlocker/AppTrackerDataSetProvider.swift',
                               'DuckDuckGo/ContentBlocker/trackerData.json',
                               'DuckDuckGo/ContentBlocker/macos-config.json'
                             ])
        }.freeze

      def self.update_embedded_files(platform, other_action)
        perf_test_warning = !other_action.tds_perf_test
        Actions.sh("./scripts/update_embedded.sh")

        # Verify no unexpected files were modified
        git_status = Actions.sh('git', 'status')
        modified_files = git_status.split("\n").select { |line| line.include?('modified:') }
        modified_files = modified_files.map { |str| str.split(':')[1].strip.delete_prefix('../') }

        modified_files.each do |modified_file|
          UI.abort_with_message!("Unexpected change to #{modified_file}.") unless UPGRADABLE_EMBEDDED_FILES[platform].any? do |s|
            s.include?(modified_file)
          end
        end

        # Everything looks good: commit and push
        unless modified_files.empty?
          modified_files.each { |modified_file| Actions.sh('git', 'add', modified_file.to_s) }
          Actions.sh('git', 'commit', '-m', 'Update embedded files')
          other_action.ensure_git_status_clean
        end

        perf_test_warning
      end

      def pre_update_embedded_tests
        tds_perf_test_result = other_action.tds_perf_test

        unless tds_perf_test_result
          UI.important("TDS performance tests failed. Make sure to validate performance before releasing to public users.")
          return false
        end

        return true
      end
    end
  end
end
