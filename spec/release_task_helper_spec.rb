describe Fastlane::Helper::ReleaseTaskHelper do
  describe "#construct_release_task_description" do
    let (:template_file) { "template.html.erb" }
    let (:release_notes) { "<ul><li>Release note 1</li><li>Release note 2</li><li>Release note 3</li></ul>" }
    let (:task_ids) { ["1", "2", "3"] }

    it "constructs release task description" do
      html_notes = "<body><h1>Hello</h1></body>"
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:path_for_asset_file).and_return(template_file)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:process_erb_template).and_return(html_notes)
      allow(Fastlane::Helper::AsanaHelper).to receive(:sanitize_asana_html_notes).and_call_original
      expect(construct_release_task_description(release_notes, task_ids)).to eq(html_notes)

      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:path_for_asset_file).with("release_task_helper/templates/release_task_description.html.erb")
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:process_erb_template).with(template_file, {
        release_notes: release_notes,
        task_ids: task_ids
      })
      expect(Fastlane::Helper::AsanaHelper).to have_received(:sanitize_asana_html_notes).with(html_notes)
    end

    it "correctly processes the template" do
      allow(Fastlane::Helper::AsanaHelper).to receive(:sanitize_asana_html_notes) do |html_notes|
        html_notes
      end

      expected = <<~EXPECTED
        <body>
          <strong>Note: This task's description is managed automatically.</strong><br>
          Only the <em>Release notes</em> section below should be modified manually.<br>
          Please do not adjust formatting.<br>
          <h1>Release notes</h1>
          <ul><li>Release note 1</li><li>Release note 2</li><li>Release note 3</li></ul>
          <h2>This release includes:</h2>
          <ul>
        #{'  '}
            <li><a data-asana-gid="1"/></li>
        #{'  '}
            <li><a data-asana-gid="2"/></li>
        #{'  '}
            <li><a data-asana-gid="3"/></li>
        #{'  '}
          </ul>
        </body>
      EXPECTED
      expect(construct_release_task_description(release_notes, task_ids)).to eq(expected)
    end

    def construct_release_task_description(release_notes, task_ids)
      Fastlane::Helper::ReleaseTaskHelper.construct_release_task_description(release_notes, task_ids)
    end
  end

  describe "#construct_release_announcement_task_description" do
    let (:template_file) { "template.html.erb" }
    let (:version) { "1.0.0" }
    let (:release_notes) { "<ul><li>Release note 1</li><li>Release note 2</li><li>Release note 3</li></ul>" }
    let (:task_ids) { ["1", "2", "3"] }

    it "constructs release announcement task description" do
      html_notes = "<body><h1>Hello</h1></body>"
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:path_for_asset_file).and_return(template_file)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:process_erb_template).and_return(html_notes)
      allow(Fastlane::Helper::AsanaHelper).to receive(:sanitize_asana_html_notes).and_call_original

      expect(construct_release_announcement_task_description(version, release_notes, task_ids)).to eq(html_notes)

      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:path_for_asset_file).with("release_task_helper/templates/release_announcement_task_description.html.erb")
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:process_erb_template).with(template_file, {
        marketing_version: version,
        release_notes: release_notes,
        task_ids: task_ids
      })
      expect(Fastlane::Helper::AsanaHelper).to have_received(:sanitize_asana_html_notes).with(html_notes)
    end

    it "correctly processes the template" do
      allow(Fastlane::Helper::AsanaHelper).to receive(:sanitize_asana_html_notes) do |html_notes|
        html_notes
      end

      expected = <<~EXPECTED
        <body>
          As the last step of the process, post a message to <a href='https://app.asana.com/0/11984721910118/1204991209236659'>REVIEW / RELEASE</a> Asana project:
          <ul>
            <li>Set the title to <strong>macOS App Release 1.0.0</strong></li>
            <li>Copy the content below (between separators) and paste as the message body.</li>
          </ul>
          <hr>
          <h1>Release notes</h1>
          <ul><li>Release note 1</li><li>Release note 2</li><li>Release note 3</li></ul>
          <h2>This release includes:</h2>
          <ul>
        #{'  '}
            <li><a data-asana-gid="1"/></li>
        #{'  '}
            <li><a data-asana-gid="2"/></li>
        #{'  '}
            <li><a data-asana-gid="3"/></li>
        #{'  '}
          </ul>
          <strong>Rollout</strong><br>
          This is now rolling out to users. New users will receive this release immediately,#{' '}
          existing users will receive this gradually over the next few days. You can force an update now#{' '}
          by going to the DuckDuckGo menu in the menu bar and selecting "Check For Updates".
          <hr>
        </body>
      EXPECTED
      expect(construct_release_announcement_task_description(version, release_notes, task_ids)).to eq(expected)
    end

    def construct_release_announcement_task_description(version, release_notes, task_ids)
      Fastlane::Helper::ReleaseTaskHelper.construct_release_announcement_task_description(version, release_notes, task_ids)
    end
  end

  describe "#extract_release_notes" do
    let (:task_body) { "Task body" }

    it "extracts html release notes by default" do
      helper = double("AsanaReleaseNotesExtractor")
      allow(Fastlane::Helper::AsanaReleaseNotesExtractor).to receive(:new).and_return(helper)
      allow(helper).to receive(:extract_release_notes).and_return("Release notes")

      expect(extract_release_notes(task_body)).to eq("Release notes")

      expect(Fastlane::Helper::AsanaReleaseNotesExtractor).to have_received(:new).with(output_type: "html")
      expect(helper).to have_received(:extract_release_notes).with(task_body)
    end

    it "passes output type to the extractor" do
      helper = double("AsanaReleaseNotesExtractor")
      allow(Fastlane::Helper::AsanaReleaseNotesExtractor).to receive(:new).and_return(helper)
      allow(helper).to receive(:extract_release_notes).and_return("Release notes")

      expect(extract_release_notes(task_body, output_type: "asana")).to eq("Release notes")

      expect(Fastlane::Helper::AsanaReleaseNotesExtractor).to have_received(:new).with(output_type: "asana")
      expect(helper).to have_received(:extract_release_notes).with(task_body)
    end

    def extract_release_notes(task_body, output_type: "html")
      Fastlane::Helper::ReleaseTaskHelper.extract_release_notes(task_body, output_type: output_type)
    end
  end
end
