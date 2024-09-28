require "fastlane_core/ui/ui"
require_relative "ddg_apple_automation_helper"
require_relative "github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class ReleaseTaskHelper
      START_MARKER = "release notes"
      PP_MARKER = /^for privacy pro subscribers:?$/
      END_MARKER = "this release includes:"
      PLACEHOLDER = "add release notes here"

      def initialize(mode = "html")
        @mode = mode
        @notes = ""
        @pp_notes = ""
        @is_capturing = false
        @is_capturing_pp = false
        @has_content = false
      end

      def html_escape(input)
        input.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def make_links(input)
        input.gsub(%r{(https://[^\s]*)}) { "<a href=\"#{$1}\">#{$1}</a>" }
      end

      def add_to_notes(line)
        @notes += line
        @notes += "\n" unless @mode == "asana"
      end

      def add_to_pp_notes(line)
        @pp_notes += line
        @pp_notes += "\n" unless @mode == "asana"
      end

      def add_release_note(release_note)
        processed_release_note =
          if @mode == "raw"
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

      def extract_release_notes(task_body)
        task_body.each_line do |line|
          lowercase_line = line.downcase.strip

          if lowercase_line == START_MARKER
            @is_capturing = true
            case @mode
            when "asana"
              add_to_notes("<ul>")
            when "html"
              add_to_notes("<h3 style=\"font-size:14px\">What's new</h3>")
              add_to_notes("<ul>")
            end
          elsif PP_MARKER && lowercase_line =~ PP_MARKER
            @is_capturing_pp = true
            case @mode
            when "asana"
              add_to_pp_notes("</ul><h2>For Privacy Pro subscribers</h2><ul>")
            when "html"
              add_to_pp_notes("</ul>")
              add_to_pp_notes("<h3 style=\"font-size:14px\">For Privacy Pro subscribers</h3>")
              add_to_pp_notes("<ul>")
            else
              add_to_pp_notes(line)
            end
          elsif END_MARKER && lowercase_line == END_MARKER
            if !@pp_notes.empty? && !@pp_notes.downcase.include?(PLACEHOLDER)
              @notes += @pp_notes
            end
            add_to_notes("</ul>") unless @mode == "raw"
            return @notes
          elsif @is_capturing && !line.strip.empty?
            @has_content = true
            add_release_note(line.strip)
          end
        end

        UI.user_error!("No release notes found") unless has_content

        @notes
      end
    end
  end
end
