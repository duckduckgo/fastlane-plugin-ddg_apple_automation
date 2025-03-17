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
    class PerfTestingHelper
      def self.test_tds_embedded_files(other_action)
        tds_perf_test_result = other_action.tds_perf_test(
          ut_file_name: "your_ut_file_name.json",
          ut_url: "https://example.com/your_ut_file.json",
          ref_file_name: "your_ref_file_name.json",
          ref_url: "https://example.com/your_ref_file.json"
        )

        unless tds_perf_test_result
          UI.important("TDS performance tests failed. Proceeding with caution.")
        end
      end
    end
  end
end
