require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require "tmpdir"
require "fileutils"
require_relative "../helper/embedded_files_helper"

module Fastlane
  module Actions
    class UpdateEmbeddedAction < Action
      def self.run(params)
        Helper::EmbeddedFilesHelper.update_embedded_files(params[:platform], other_action)
      end

      def self.description
        "Runs performance tests for Tracker Radar Kit with specified TDS files"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.platform
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
