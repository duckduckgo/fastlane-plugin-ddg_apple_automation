describe Fastlane::Actions::AsanaCreateActionItemAction do
  describe "#run" do
    let(:task_url) { "https://app.asana.com/4/753241/9999" }
    let(:task_id) { "1" }
    let(:automation_subtask_id) { "2" }
    let(:assignee_id) { "11" }
    let(:github_handle) { "user" }
    let(:task_name) { "example name" }

    let(:parsed_yaml_content) { { 'name' => 'test task', 'html_notes' => '<p>Some notes</p>' } }

    before do
      @asana_client_tasks = double
      asana_client = double("Asana::Client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)

      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:extract_asana_task_id).and_return(task_id)
      allow(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run).and_return(assignee_id)
      allow(Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction).to receive(:run).with(task_url: task_url, asana_access_token: anything).and_return(automation_subtask_id)
      allow(Fastlane::Actions::AsanaGetUserIdForGithubHandleAction).to receive(:run).and_return(assignee_id)
      allow(@asana_client_tasks).to receive(:create_subtask_for_task)

      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
    end

    it "extracts assignee id from release task when is scheduled release" do
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:extract_asana_task_id).with(task_url)
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run).with(
        task_id: task_id,
        asana_access_token: anything
      )
      test_action(task_url: task_url, is_scheduled_release: true)
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_assignee_id", "11")
    end

    it "takes assignee id from github handle when is manual release" do
      expect(Fastlane::Actions::AsanaGetUserIdForGithubHandleAction).to receive(:run).with(
        github_handle: github_handle,
        asana_access_token: anything
      )
      test_action(task_url: task_url, is_scheduled_release: false, github_handle: github_handle)
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_assignee_id", "11")
    end

    it "raises an error when github handle is empty and is manual release" do
      expect(Fastlane::UI).to receive(:user_error!).with("Github handle cannot be empty for manual release")
      test_action(task_url: task_url, is_scheduled_release: false, github_handle: "")
      expect(Fastlane::Helper::GitHubActionsHelper).not_to have_received(:set_output)
    end

    it "correctly builds payload if notes input is given" do
      test_action(task_url: task_url, task_name: task_name, notes: "notes", is_scheduled_release: true)
      expect(@asana_client_tasks).to have_received(:create_subtask_for_task).with(
        task_gid: automation_subtask_id,
        name: task_name,
        notes: "notes",
        assignee: assignee_id
      )
    end

    it "correctly builds payload if html_notes input is given" do
      test_action(task_url: task_url, task_name: task_name, html_notes: "html_notes", is_scheduled_release: true)
      expect(@asana_client_tasks).to have_received(:create_subtask_for_task).with(
        task_gid: automation_subtask_id,
        name: task_name,
        html_notes: "html_notes",
        assignee: assignee_id
      )
    end

    it "correctly builds payload if template_name input is given" do
      allow(File).to receive(:read)
      allow(YAML).to receive(:safe_load).and_return(parsed_yaml_content)
      allow(ERB).to receive(:new).and_return(double('erb', result: "yaml"))
      test_action(task_url: task_url, task_name: task_name, template_name: "template_name", is_scheduled_release: true)
      expect(@asana_client_tasks).to have_received(:create_subtask_for_task).with(
        task_gid: automation_subtask_id,
        name: "test task",
        html_notes: "<p>Some notes</p>",
        assignee: assignee_id
      )
    end

    it "raises an error if adding subtask fails" do
      allow(Fastlane::UI).to receive(:user_error!)
      allow(@asana_client_tasks).to receive(:create_subtask_for_task).and_raise(StandardError, 'API Error')
      test_action(task_url: task_url, task_name: task_name, notes: "notes", is_scheduled_release: true)
      expect(Fastlane::UI).to have_received(:user_error!).with("Failed to create subtask for task: API Error")
    end

    it "correctly sets output" do
      allow(@asana_client_tasks).to receive(:create_subtask_for_task).and_return(double('subtask', gid: "42"))
      test_action(task_url: task_url, task_name: task_name, notes: "notes", is_scheduled_release: true)
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_new_task_id", "42")
    end

    def test_action(task_url:, task_name: nil, notes: nil, html_notes: nil, template_name: nil, is_scheduled_release: false, github_handle: nil)
      Fastlane::Actions::AsanaCreateActionItemAction.run(
        task_url: task_url,
        task_name: task_name,
        notes: notes,
        html_notes: html_notes,
        template_name: template_name,
        is_scheduled_release: is_scheduled_release,
        github_handle: github_handle
      )
    end
  end

  describe "#process_yaml_template" do
    it "processes appcast-failed-hotfix template" do
      expected_name = "Generate appcast2.xml for 1.0.0-123 hotfix release and upload assets to S3"
      expected_notes = <<~EXPECTED
        <body>
          Publishing 1.0.0-123 hotfix release failed in CI. Please follow the steps to generate the appcast file and upload files to S3 from your local machine.<br>
          <ol>
            <li>Create a new file called <code>release-notes.txt</code> on your disk.
              <ul>
                <li>Add each release note as a separate line and don't add bullet points (•) – the script will add them automatically.</li>
              </ul></li>
            <li>Run <code>appcastManager</code>:
              <ul>
                <li><code>./scripts/appcast_manager/appcastManager.swift --release-hotfix-to-public-channel --dmg ~/Downloads/duckduckgo-1.0.0.123.dmg --release-notes release-notes.txt</code></li>
              </ul></li>
            <li>Verify that the new build is in the appcast file with the latest release notes and no internal channel tag. The phased rollout tag should <em>not</em> be present:
              <ul>
                <li><code>&lt;sparkle:phasedRolloutInterval&gt;43200&lt;/sparkle:phasedRolloutInterval&gt;</code></li>
              </ul></li>
            <li>Run <code>upload_to_s3.sh</code> script:
              <ul>
                <li><code>./scripts/upload_to_s3/upload_to_s3.sh --run --overwrite-duckduckgo-dmg 1.0.0.123</code></li>
              </ul></li>
          </ol>
          When done, please verify that "Check for Updates" works correctly:
          <ol>
            <li>Launch a debug version of the app with an old version number.</li>
            <li>Make sure you're not identified as an internal user in the app.</li>
            <li>Go to Main Menu → DuckDuckGo → Check for Updates...</li>
            <li>Verify that you're being offered to update to 1.0.0-123.</li>
            <li>Verify that the update works.</li>
          </ol><br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("appcast-failed-hotfix", {
        "tag" => "1.0.0-123",
        "dmg_name" => "duckduckgo-1.0.0.123.dmg",
        "version" => "1.0.0.123",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes appcast-failed-internal template" do
      expected_name = "Generate appcast2.xml for 1.0.0-123 internal release and upload assets to S3"
      expected_notes = <<~EXPECTED
        <body>
          Publishing 1.0.0-123 internal release failed in CI. Please follow the steps to generate the appcast file and upload files to S3 from your local machine.<br>
          <ol>
            <li>Download <a href='https://cdn.com/duckduckgo-1.0.0.123.dmg'>the DMG for 1.0.0-123 release</a>.</li>
            <li>Create a new file called <code>release-notes.txt</code> on your disk.
              <ul>
                <li>Add each release note as a separate line and don't add bullet points (•) – the script will add them automatically.</li>
              </ul></li>
            <li>Run <code>appcastManager</code>:
              <ul>
                <li><code>./scripts/appcast_manager/appcastManager.swift --release-to-internal-channel --dmg ~/Downloads/duckduckgo-1.0.0.123.dmg --release-notes release-notes.txt</code></li>
              </ul></li>
            <li>Verify that the new build is in the appcast file with the following internal channel tag:
              <ul>
                <li><code>&lt;sparkle:channel&gt;internal-channel&lt;/sparkle:channel&gt;</code></li>
              </ul></li>
            <li>Run <code>upload_to_s3.sh</code> script:
              <ul>
                <li><code>./scripts/upload_to_s3/upload_to_s3.sh --run</code></li>
              </ul></li>
          </ol>
          When done, please verify that "Check for Updates" works correctly:
          <ol>
            <li>Launch a debug version of the app with an old version number.</li>
            <li>Identify as an internal user in the app.</li>
            <li>Go to Main Menu → DuckDuckGo → Check for Updates...</li>
            <li>Verify that you're being offered to update to 1.0.0-123.</li>
            <li>Verify that the update works.</li>
          </ol><br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("appcast-failed-internal", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/duckduckgo-1.0.0.123.dmg",
        "dmg_name" => "duckduckgo-1.0.0.123.dmg",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    def process_yaml_template(template_name, args)
      Fastlane::Actions::AsanaCreateActionItemAction.process_yaml_template(template_name, args)
    end
  end
end
