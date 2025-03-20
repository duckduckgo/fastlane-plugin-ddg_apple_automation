require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"

module Fastlane
  module Actions
    class TdsPerfTestAction < Action
      # Define platform-specific constants
      IOS_TEST_PARAMS = {
        ut_file_name: "ios-tds.json",
        ut_url: "https://staticcdn.duckduckgo.com/trackerblocking/v5/current/",
        ref_file_name: "trackerData.json",
        ref_url: "https://raw.githubusercontent.com/duckduckgo/apple-browsers/refs/heads/main/iOS/Core/"
      }.freeze

      MAC_TEST_PARAMS = {
        ut_file_name: "macos-tds.json",
        ut_url: "https://staticcdn.duckduckgo.com/trackerblocking/v6/current/",
        ref_file_name: "trackerData.json",
        ref_url: "https://raw.githubusercontent.com/duckduckgo/apple-browsers/refs/heads/main/macOS/DuckDuckGo/ContentBlocker/"
      }.freeze

      def self.run(params)
        UI.message("Starting TDS Performance Testing...")

        # Determine platform and set default parameters if needed
        platform = lane_context[SharedValues::PLATFORM_NAME]
        default_params = platform == :ios ? IOS_TEST_PARAMS : MAC_TEST_PARAMS

        # Use provided parameters or defaults
        ut_file_name = params[:ut_file_name] || default_params[:ut_file_name]
        ut_url = params[:ut_url] || default_params[:ut_url]
        ref_file_name = params[:ref_file_name] || default_params[:ref_file_name]
        ref_url = params[:ref_url] || default_params[:ref_url]

        UI.message("Using TDS parameters for #{platform} platform:")
        UI.message("  Under-test file: #{ut_file_name}")
        UI.message("  Under-test URL: #{ut_url}")
        UI.message("  Reference file: #{ref_file_name}")
        UI.message("  Reference URL: #{ref_url}")

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
              # Build for testing
              begin
                Actions.sh("xcodebuild build-for-testing -scheme TrackerRadarKit -destination 'platform=macOS'")
              rescue StandardError => e
                UI.error("Failed to build for testing: #{e}")
                false
              end

              # Set environment variables and run test
              test_command = [
                "env",
                "TEST_RUNNER_TDS_UT_FILE_NAME=#{ut_file_name}",
                "TEST_RUNNER_TDS_UT_URL=#{ut_url}",
                "TEST_RUNNER_TDS_REF_FILE_NAME=#{ref_file_name}",
                "TEST_RUNNER_TDS_REF_URL=#{ref_url}",
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
        ["Lorenzo Mattei"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :ut_file_name,
            env_name: "TEST_RUNNER_TDS_UT_FILE_NAME",
            description: "The file name for the under-test TDS",
            type: String,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :ut_url,
            env_name: "TEST_RUNNER_TDS_UT_URL",
            description: "The URL for the under-test TDS",
            type: String,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :ref_file_name,
            env_name: "TEST_RUNNER_TDS_REF_FILE_NAME",
            description: "The file name for the reference TDS",
            type: String,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :ref_url,
            env_name: "TEST_RUNNER_TDS_REF_URL",
            description: "The URL for the reference TDS",
            type: String,
            optional: true
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
