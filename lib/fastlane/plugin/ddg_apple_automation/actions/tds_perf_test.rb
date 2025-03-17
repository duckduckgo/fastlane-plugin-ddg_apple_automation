require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"

module Fastlane
  module Actions
    class TdsPerfTestAction < Action
      def self.run(params)
        UI.message("Starting TDS Performance Testing...")

        # Create temporary directory
        tmp_dir = "#{ENV.fetch('TMPDIR', nil)}/tds-perf-testing"

        begin
          Actions.sh("mkdir -p \"#{tmp_dir}\"")

          # Navigate to temp directory
          Dir.chdir(tmp_dir) do
            # Clone repository
            Actions.sh("git clone --depth=1 git@github.com:duckduckgo/TrackerRadarKit.git")

            # Navigate to cloned repository
            Dir.chdir("TrackerRadarKit") do
              # Set environment variables and run test
              test_command = [
                "env",
                "TEST_RUNNER_TDS_UT_FILE_NAME=#{params[:ut_file_name]}",
                "TEST_RUNNER_TDS_UT_URL=#{params[:ut_url]}",
                "TEST_RUNNER_TDS_REF_FILE_NAME=#{params[:ref_file_name]}",
                "TEST_RUNNER_TDS_REF_URL=#{params[:ref_url]}",
                "xcodebuild test-without-building",
                "-scheme TrackerRadarKit",
                "-destination 'platform=macOS'",
                "-only-testing:TrackerRadarKitPerformanceTests/NextTrackerDataSetPerformanceTests"
              ].join(" ")

              begin
                Actions.sh(test_command)
                true
              rescue StandardError => e
                UI.error("Performance tests failed: #{e}")
                false
              end
            end
          end
        ensure
          # Cleanup step - always executed regardless of success or failure
          UI.message("Cleaning up temporary test directory...")
          Actions.sh("rm -rf \"#{tmp_dir}\"")
        end
      end

      def self.description
        "Runs performance tests for Tracker Radar Kit with specified TDS files"
      end

      def self.authors
        ["Your Name"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :ut_file_name,
            env_name: "TEST_RUNNER_TDS_UT_FILE_NAME",
            description: "The file name for the under-test TDS",
            type: String,
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :ut_url,
            env_name: "TEST_RUNNER_TDS_UT_URL",
            description: "The URL for the under-test TDS",
            type: String,
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :ref_file_name,
            env_name: "TEST_RUNNER_TDS_REF_FILE_NAME",
            description: "The file name for the reference TDS",
            type: String,
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :ref_url,
            env_name: "TEST_RUNNER_TDS_REF_URL",
            description: "The URL for the reference TDS",
            type: String,
            optional: false
          )
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end

      def self.return_value
        "Returns true if tests passed, false otherwise"
      end
    end
  end
end
