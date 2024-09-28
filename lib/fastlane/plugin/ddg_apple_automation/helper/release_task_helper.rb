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

      def self.html_escape(input)
        input.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def self.make_links(input)
        input.gsub(%r{(https://[^\s]*)}) { "<a href=\"#{$1}\">#{$1}</a>" }
      end

      def self.add_to_notes(notes, line, mode)
        notes += line
        notes += "\n" unless mode == "asana"
        notes
      end

      def self.add_release_note(notes, pp_notes, release_note, is_capturing_pp, mode)
        processed_release_note =
          if mode == "raw"
            release_note
          else
            "<li>#{make_links(html_escape(release_note))}</li>"
          end

        if is_capturing_pp
          add_to_notes(pp_notes, processed_release_note, mode)
        else
          add_to_notes(notes, processed_release_note, mode)
        end
      end

      def self.extract_release_notes(task_body, mode = "html")
        is_capturing = false
        is_capturing_pp = false
        has_content = false
        notes = ""
        pp_notes = ""

        output = mode
        case mode
        when "asana"
          output = "asana"
        when "raw"
          output = "raw"
        end

        task_body.each_line do |line|
          lowercase_line = line.downcase.strip

          if lowercase_line == START_MARKER
            is_capturing = true
            case output
            when "asana"
              notes = add_to_notes(notes, "<ul>", output)
            when "html"
              notes = add_to_notes(notes, "<h3 style=\"font-size:14px\">What's new</h3>", output)
              notes = add_to_notes(notes, "<ul>", output)
            end
          elsif PP_MARKER && lowercase_line =~ PP_MARKER
            is_capturing_pp = true
            case output
            when "asana"
              pp_notes = add_to_notes(pp_notes, "</ul><h2>For Privacy Pro subscribers</h2><ul>", output)
            when "html"
              pp_notes = add_to_notes(pp_notes, "</ul>", output)
              pp_notes = add_to_notes(pp_notes, "<h3 style=\"font-size:14px\">For Privacy Pro subscribers</h3>", output)
              pp_notes = add_to_notes(pp_notes, "<ul>", output)
            else
              pp_notes = add_to_notes(pp_notes, line, output)
            end
          elsif END_MARKER && lowercase_line == END_MARKER
            if !pp_notes.empty? && !pp_notes.downcase.include?(PLACEHOLDER)
              notes += pp_notes
            end
            notes = add_to_notes(notes, "</ul>", mode) unless output == "raw"
            return notes
          elsif is_capturing && !line.strip.empty?
            has_content = true
            if is_capturing_pp
              pp_notes = add_release_note(notes, pp_notes, line.strip, is_capturing_pp, output)
            else
              notes = add_release_note(notes, pp_notes, line.strip, is_capturing_pp, output)
            end
          end
        end

        notes
      end
    end
  end
end
