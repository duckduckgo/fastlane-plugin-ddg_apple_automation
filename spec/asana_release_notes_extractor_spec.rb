describe Fastlane::Helper::AsanaReleaseNotesExtractor do
  shared_context "placeholder release notes with placeholder Privacy Pro section" do
    before do
      @input = <<-INPUT
Note: This task's description is managed automatically.
Only the Release notes section below should be modified manually.
Please do not adjust formatting.

Release notes

  <-- Add release notes here -->

For DuckDuckGo subscribers

  <-- Add release notes here -->

This release includes:
      INPUT

      raw = <<-RAW
<-- Add release notes here -->
      RAW

      html = <<-HTML
<h3 style="font-size:14px">What's new</h3>
<ul>
<li>&lt;-- Add release notes here --&gt;</li>
</ul>
      HTML

      asana = <<-ASANA
<ul><li>&lt;-- Add release notes here --&gt;</li></ul>
      ASANA

      @output = {
        raw: raw,
        html: html,
        asana: asana.chomp
      }
    end
  end

  shared_context "non-empty release notes with non-empty Privacy Pro section" do
    before do
      @input = <<-INPUT
Note: This task's description is managed automatically.
Only the Release notes section below should be modified manually.
Please do not adjust formatting.

Release notes

  You can now find browser windows listed in the "Window" app menu and in the Dock menu.
  We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
  When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
  The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.

For DuckDuckGo subscribers

  VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
  Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.

This release includes:

  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
      INPUT

      raw = <<-RAW
You can now find browser windows listed in the "Window" app menu and in the Dock menu.
We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
For DuckDuckGo subscribers
VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.
      RAW

      html = <<-HTML
<h3 style="font-size:14px">What's new</h3>
<ul>
<li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li>
<li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li>
<li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li>
<li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li>
</ul>
<h3 style="font-size:14px">For DuckDuckGo subscribers</h3>
<ul>
<li>VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.</li>
<li>Visit <a href="https://duckduckgo.com/pro">https://duckduckgo.com/pro</a> for more information. Privacy Pro is currently available to U.S. residents only.</li>
</ul>
      HTML

      asana = <<-ASANA
<ul><li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li><li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li><li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li><li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li></ul><h2>For DuckDuckGo subscribers</h2><ul><li>VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.</li><li>Visit <a href="https://duckduckgo.com/pro">https://duckduckgo.com/pro</a> for more information. Privacy Pro is currently available to U.S. residents only.</li></ul>
      ASANA

      @output = {
        raw: raw,
        html: html,
        asana: asana.chomp
      }
    end
  end

  shared_context "non-empty release notes and missing Privacy Pro section" do
    before do
      @input = <<-INPUT
Note: This task's description is managed automatically.
Only the Release notes section below should be modified manually.
Please do not adjust formatting.

Release notes

  You can now find browser windows listed in the "Window" app menu and in the Dock menu.
  We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
  When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
  The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.

This release includes:

  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
      INPUT

      raw = <<-RAW
You can now find browser windows listed in the "Window" app menu and in the Dock menu.
We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
      RAW

      html = <<-HTML
<h3 style="font-size:14px">What's new</h3>
<ul>
<li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li>
<li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li>
<li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li>
<li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li>
</ul>
      HTML

      asana = <<-ASANA
<ul><li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li><li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li><li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li><li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li></ul>
      ASANA

      @output = {
        raw: raw,
        html: html,
        asana: asana.chomp
      }
    end
  end

  shared_context "non-empty release notes and a placeholder Privacy Pro section" do
    before do
      @input = <<-INPUT
Note: This task's description is managed automatically.
Only the Release notes section below should be modified manually.
Please do not adjust formatting.

Release notes

  You can now find browser windows listed in the "Window" app menu and in the Dock menu.
  We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
  When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
  The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.

For DuckDuckGo subscribers

  <-- Add release notes here -->

This release includes:

  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
      INPUT

      raw = <<-RAW
You can now find browser windows listed in the "Window" app menu and in the Dock menu.
We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
      RAW

      html = <<-HTML
<h3 style="font-size:14px">What's new</h3>
<ul>
<li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li>
<li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li>
<li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li>
<li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li>
</ul>
      HTML

      asana = <<-ASANA
<ul><li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li><li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li><li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li><li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li></ul>
      ASANA

      @output = {
        raw: raw,
        html: html,
        asana: asana.chomp
      }
    end
  end

  shared_context "non-empty release notes and Privacy Pro release header as a bullet point inside regular release notes" do
    before do
      @input = <<-INPUT
Note: This task's description is managed automatically.
Only the Release notes section below should be modified manually.
Please do not adjust formatting.

Release notes

  You can now find browser windows listed in the "Window" app menu and in the Dock menu.
  We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
  When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
  The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
  For DuckDuckGo subscribers
  VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
  Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.

This release includes:

  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
  https://app.asana.com/0/0/0/f/
      INPUT

      raw = <<-RAW
You can now find browser windows listed in the "Window" app menu and in the Dock menu.
We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
For DuckDuckGo subscribers
VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.
      RAW

      html = <<-HTML
<h3 style="font-size:14px">What's new</h3>
<ul>
<li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li>
<li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li>
<li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li>
<li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li>
</ul>
<h3 style="font-size:14px">For DuckDuckGo subscribers</h3>
<ul>
<li>VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.</li>
<li>Visit <a href="https://duckduckgo.com/pro">https://duckduckgo.com/pro</a> for more information. Privacy Pro is currently available to U.S. residents only.</li>
</ul>
      HTML

      asana = <<-ASANA
<ul><li>You can now find browser windows listed in the &quot;Window&quot; app menu and in the Dock menu.</li><li>We also added &quot;Duplicate Tab&quot; to the app menu so you can use it as an action in Apple Shortcuts.</li><li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li><li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li></ul><h2>For DuckDuckGo subscribers</h2><ul><li>VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.</li><li>Visit <a href="https://duckduckgo.com/pro">https://duckduckgo.com/pro</a> for more information. Privacy Pro is currently available to U.S. residents only.</li></ul>
      ASANA

      @output = {
        raw: raw,
        html: html,
        asana: asana.chomp
      }
    end
  end

  shared_context "empty task body" do
    before do
      @input = ""
    end
  end

  shared_examples "extracting release notes" do |mode|
    it "extracts release notes in #{mode} format" do
      expect(subject.extract_release_notes(@input)).to eq(@output[mode.to_sym])
    end
  end

  ["html", "asana", "raw"].each do |mode|
    context "#{mode} mode" do
      subject { Fastlane::Helper::AsanaReleaseNotesExtractor.new(output_type: mode) }

      context "placeholder release notes with placeholder Privacy Pro section" do
        include_context "placeholder release notes with placeholder Privacy Pro section"
        it_behaves_like "extracting release notes", mode
      end

      context "non-empty release notes with non-empty Privacy Pro section" do
        include_context "non-empty release notes with non-empty Privacy Pro section"
        it_behaves_like "extracting release notes", mode
      end

      context "non-empty release notes and missing Privacy Pro section" do
        include_context "non-empty release notes and missing Privacy Pro section"
        it_behaves_like "extracting release notes", mode
      end

      context "non-empty release notes and a placeholder Privacy Pro section" do
        include_context "non-empty release notes and a placeholder Privacy Pro section"
        it_behaves_like "extracting release notes", mode
      end

      context "non-empty release notes and Privacy Pro release header as a bullet point inside regular release notes" do
        include_context "non-empty release notes and Privacy Pro release header as a bullet point inside regular release notes"
        it_behaves_like "extracting release notes", mode
      end

      context "empty task body" do
        include_context "empty task body"

        before do
          allow(Fastlane::UI).to receive(:user_error!)
        end

        it "shows error" do
          subject.extract_release_notes(@input)

          expect(Fastlane::UI).to have_received(:user_error!).with("No release notes found")
        end
      end
    end
  end
end
