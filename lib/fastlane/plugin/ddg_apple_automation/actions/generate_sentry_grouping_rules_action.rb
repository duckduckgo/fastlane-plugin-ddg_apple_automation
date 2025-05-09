require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require "tmpdir"
require "fileutils"
require_relative "../helper/sentry_helper"

module Fastlane
  module Actions
    class GenerateSentryGroupingRulesAction < Action
      def self.run(params)
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        Helper::SentryHelper.generate_grouping_rules(params[:platform], params[:output_file])
      end

      def self.description
        "Generate Sentry Grouping Rules (to treat symbols from local packages as app symbols)"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :output_file,
                                       description: "File to write the grouping rules to",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.return_value
        "The generated Sentry grouping rules in a newline-separated list"
      end
    end
  end
end
