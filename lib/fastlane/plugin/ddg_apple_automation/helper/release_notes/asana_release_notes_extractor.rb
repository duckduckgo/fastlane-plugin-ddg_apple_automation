require "fastlane_core/ui/ui"
require_relative "../ddg_apple_automation_helper"
require_relative "../github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AsanaReleaseNotesExtractor
      START_MARKER = "release notes"
      PP_MARKER = /^for duckduckgo subscribers:?$/
      END_MARKER = "this release includes:"
      PLACEHOLDER = "add release notes here"

      def initialize(output_type: "html")
        @output_type = output_type
        @notes = ""
        @pp_notes = ""
        @is_capturing = false
        @is_capturing_pp = false
        @has_content = false
      end

      def extract_release_notes(task_body)
        task_body.each_line do |line|
          lowercase_line = line.downcase.strip

          if lowercase_line == START_MARKER
            handle_start_marker
          elsif lowercase_line =~ PP_MARKER
            handle_pp_marker(line)
          elsif lowercase_line == END_MARKER
            handle_end_marker
            return @notes
          elsif @is_capturing && !line.strip.empty?
            @has_content = true
            add_release_note(line.strip)
          end
        end

        UI.user_error!("No release notes found") unless @has_content

        @notes
      end

      private

      def html_escape(input)
        input.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def make_links(input)
        input.gsub(%r{(https://[^\s]*)}) { "<a href=\"#{$1}\">#{$1}</a>" }
      end

      def add_to_notes(line)
        @notes += line
        @notes += "\n" unless @output_type == "asana"
      end

      def add_to_pp_notes(line)
        @pp_notes += line
        @pp_notes += "\n" unless @output_type == "asana"
      end

      def add_release_note(release_note)
        processed_release_note =
          if @output_type == "raw"
            release_note
          else
            "<li>#{make_links(html_escape(release_note))}</li>"
          end

        if @is_capturing_pp
          add_to_pp_notes(processed_release_note)
        else
          add_to_notes(processed_release_note)
        end
      end

      def handle_start_marker
        @is_capturing = true
        case @output_type
        when "asana"
          add_to_notes("<ul>")
        when "html"
          add_to_notes("<h3 style=\"font-size:14px\">What's new</h3>")
          add_to_notes("<ul>")
        end
      end

      def handle_pp_marker(line)
        @is_capturing_pp = true
        case @output_type
        when "asana"
          add_to_pp_notes("</ul><h2>For DuckDuckGo subscribers</h2><ul>")
        when "html"
          add_to_pp_notes("</ul>")
          add_to_pp_notes("<h3 style=\"font-size:14px\">For DuckDuckGo subscribers</h3>")
          add_to_pp_notes("<ul>")
        else
          add_to_pp_notes(line.strip)
        end
      end

      def handle_end_marker
        unless @pp_notes.empty? || @pp_notes.downcase.include?(PLACEHOLDER)
          @notes += @pp_notes
        end
        add_to_notes("</ul>") unless @output_type == "raw"
      end
    end
  end
end
