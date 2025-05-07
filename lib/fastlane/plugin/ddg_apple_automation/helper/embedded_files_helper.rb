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
                               'DuckDuckGo/ContentBlocker/macos-config.json',
                               '../SharedPackages/DataBrokerProtectionCore/Sources/DataBrokerProtectionCore/Resources/JSON/*.json'
                             ])
        }.freeze

      def self.update_embedded_files(platform, other_action)
        perf_test_warning = false # !other_action.tds_perf_test
        Actions.sh("./scripts/update_embedded.sh")

        # Verify no unexpected files were modified
        git_status = fetch_git_status
        modified_files = git_status.filter_map { |state, file| file if state == 'M' }
        untracked_files = git_status.filter_map { |state, file| file if state == '??' }

        verify_file_updates_allowed(platform, modified_files, "Unexpected modified file")
        verify_file_updates_allowed(platform, untracked_files, "Unexpected untracked file")

        # Everything looks good: commit and push
        modified_files.concat(untracked_files).each { |file| Actions.sh('git', 'add', file.to_s) }

        unless system("git diff --cached --quiet")
          Actions.sh('git', 'commit', '-m', 'Update embedded files')
          other_action.ensure_git_status_clean
        end

        perf_test_warning
      end

      def self.fetch_git_status
        # Return a list of status + filename pairs.
        # To achieve this, we're splitting lines by space, allowing for 2 tokens max.
        Actions.sh('git', 'status', '-s').split("\n").map { |line| line.split(' ', 2) }
      end

      def self.verify_file_updates_allowed(platform, filenames, message)
        filenames.each do |filename|
          UI.abort_with_message!("#{message}: #{filename}.") unless UPGRADABLE_EMBEDDED_FILES[platform].any? do |pattern|
            File.fnmatch?(pattern, filename)
          end
        end
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
