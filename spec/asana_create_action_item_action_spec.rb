describe Fastlane::Actions::AsanaCreateActionItemAction do
  let(:task_url) { "https://app.asana.com/4/753241/9999" }
  let(:task_id) { "1" }
  let(:automation_subtask_id) { "2" }
  let(:assignee_id) { "11" }
  let(:github_handle) { "user" }
  let(:task_name) { "example name" }

  describe "#run" do
    before do
      @asana_client_tasks = double
      asana_client = double("Asana::Client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)

      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_id).and_return(task_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee).and_return(assignee_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:get_release_automation_subtask_id).with(task_url, anything).and_return(automation_subtask_id)
      allow(Fastlane::Actions::AsanaCreateActionItemAction).to receive(:fetch_assignee_id).and_return(assignee_id)
      allow(@asana_client_tasks).to receive(:create_subtask_for_task).and_return(double('subtask', gid: "42"))

      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
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
      parsed_yaml_content = { 'name' => 'test task', 'html_notes' => '<p>Some notes</p>' }
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:path_for_asset_file)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:process_erb_template)
      allow(YAML).to receive(:safe_load).and_return(parsed_yaml_content)
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

  describe "#fetch_assignee_id" do
    it "extracts assignee id from release task when is scheduled release" do
      expect(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee)
        .with(task_id, anything).and_return(assignee_id)
      expect(fetch_assignee_id(
               task_id: task_id,
               github_handle: github_handle,
               asana_access_token: anything,
               is_scheduled_release: true
             )).to eq(assignee_id)
    end

    it "takes assignee id from github handle when is manual release" do
      expect(Fastlane::Helper::AsanaHelper).to receive(:get_asana_user_id_for_github_handle).with(github_handle).and_return(assignee_id)
      expect(fetch_assignee_id(
               task_id: task_id,
               github_handle: github_handle,
               asana_access_token: anything,
               is_scheduled_release: false
             )).to eq(assignee_id)
    end

    it "shows error when github handle is empty and is manual release" do
      expect(Fastlane::UI).to receive(:user_error!).with("Github handle cannot be empty for manual release")
      fetch_assignee_id(
        task_id: task_id,
        github_handle: "",
        asana_access_token: anything,
        is_scheduled_release: false
      )
    end

    def fetch_assignee_id(task_id:, github_handle:, asana_access_token:, is_scheduled_release:)
      Fastlane::Actions::AsanaCreateActionItemAction.fetch_assignee_id(
        task_id: task_id,
        github_handle: github_handle,
        asana_access_token: asana_access_token,
        is_scheduled_release: is_scheduled_release
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

    it "processes appcast-failed-public template" do
      expected_name = "Generate appcast2.xml for 1.0.0-123 public release and upload assets to S3"
      expected_notes = <<~EXPECTED
        <body>
          Publishing 1.0.0-123 release failed in CI. Please follow the steps to generate the appcast file and upload files to S3 from your local machine.<br>
          <ol>
            <li>Create a new file called <code>release-notes.txt</code> on your disk.
              <ul>
                <li>Add each release note as a separate line and don't add bullet points (•) – the script will add them automatically.</li>
              </ul></li>
            <li>Run <code>appcastManager</code>:
              <ul>
                <li><code>./scripts/appcast_manager/appcastManager.swift --release-to-public-channel --version 1.0.0.123 --release-notes release-notes.txt</code></li>
              </ul></li>
            <li>Verify that the new build is in the appcast file with the latest release notes, the phased rollout tag (below) and no internal channel tag:
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

      name, notes = process_yaml_template("appcast-failed-public", {
        "tag" => "1.0.0-123",
        "version" => "1.0.0.123",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes delete-branch-failed template" do
      expected_name = "Delete release/1.0.0 branch"
      expected_notes = <<~EXPECTED
        <body>
          The <code>1.0.0-123</code> public release has been successfully tagged and published in GitHub releases,#{' '}
          but deleting <code>release/1.0.0</code> branch failed. Please delete it manually:
          <ul>
            <li><code>git push origin --delete release/1.0.0</code></li>
          </ul>
          Complete this task when ready, or if the release branch has already been deleted.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("delete-branch-failed", {
        "branch" => "release/1.0.0",
        "tag" => "1.0.0-123",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes internal-release-tag-failed template" do
      expected_name = "Tag release/1.1.0 branch and create GitHub release"
      expected_notes = <<~EXPECTED
        <body>
          Failed to tag the release with <code>1.1.0-123</code> tag.<br>
          Please follow instructions below to tag the branch, make GitHub release and merge release branch to <code>main</code> manually.<br>
          <br>
          Issue the following git commands to tag the release and merge the branch:
          <ul>
            <li><code>git fetch origin</code></li>
            <li><code>git checkout release/1.1.0</code> switch to the release branch</li>
            <li><code>git pull origin release/1.1.0</code> pull latest changes</li>
            <li><code>git tag 1.1.0-123</code> tag the release</li>
            <li><code>git push origin 1.1.0-123</code> push the tag</li>
            <li><code>git checkout main</code> switch to main</li>
            <li><code>git pull origin main</code> pull the latest code</li>
            <li><code>git merge release/1.1.0</code>
              <ul>
                <li>Resolve conflicts as needed</li>
                <li>When merging a hotfix branch into an internal release branch, you will get conflicts in version and build number xcconfig files:
                  <ul>
                    <li>In the version file: accept the internal version number (higher).</li>
                    <li>In the build number file: accept the hotfix build number (higher). This step is very important in order to calculate the build number of the next internal release correctly.</li>
                  </ul></li>
              </ul></li>
            <li><code>git push origin main</code> push merged branch</li>
          </ul><br>
          To create GitHub release:
          <ul>
            <li>Set up GH CLI if you haven't yet: <a data-asana-gid='1203791243007683'/></li>
            <li>Run the following command:
            <ul>
              <li><code>gh release create 1.1.0-123 --generate-notes --prerelease --notes-start-tag 1.0.0</code></li>
            </ul></li>
          </ul><br>
          Complete this task when ready and proceed with testing the build. If you're bumping an internal release, you should get another task asking you to publish the release in Sparkle.#{' '}
          Look for other tasks in <a data-asana-gid='12345'/> task and handle them as needed.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("internal-release-tag-failed", {
        "branch" => "release/1.1.0",
        "tag" => "1.1.0-123",
        "base_branch" => "main",
        "last_release_tag" => "1.0.0",
        "automation_task_id" => "12345",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes merge-failed template" do
      expected_name = "Merge release/1.0.0 to main"
      expected_notes = <<~EXPECTED
        <body>
          The <code>1.0.0-123</code> release has been successfully tagged and published in GitHub releases,#{' '}
          but merging to <code>main</code> failed. Please resolve conflicts and merge <code>release/1.0.0</code> to <code>main</code> manually.<br>
          <br>
          Issue the following git commands:
          <ul>
            <li><code>git fetch origin</code></li>
            <li><code>git checkout release/1.0.0</code> switch to the release branch</li>
            <li><code>git pull origin release/1.0.0</code> pull latest changes</li>
            <li><code>git checkout main</code> switch to main</li>
            <li><code>git pull origin main</code> pull the latest code</li>
            <li><code>git merge release/1.0.0</code>
              <ul>
                <li>Resolve conflicts as needed</li>
                <li>When merging a hotfix branch into an internal release branch, you will get conflicts in version and build number xcconfig files:
                  <ul>
                    <li>In the version file: accept the internal version number (higher).</li>
                    <li>In the build number file: accept the hotfix build number (higher). This step is very important in order to calculate the build number of the next internal release correctly.</li>
                  </ul></li>
              </ul></li>
            <li><code>git push origin main</code> push merged branch</li>
          </ul>
          Complete this task when ready and proceed with testing the build.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("merge-failed", {
        "branch" => "release/1.0.0",
        "base_branch" => "main",
        "tag" => "1.0.0-123",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes public-release-tag-failed template" do
      expected_name = "Tag release/1.1.0 branch, delete it, and create GitHub release"
      expected_notes = <<~EXPECTED
        <body>
          Failed to tag the release with <code>1.1.0-123</code> tag.<br>
          Please follow instructions below to tag the branch, make GitHub release and delete the release branch manually.
          <ul>
            <li>If the tag has already been created, please proceed with creating GitHub release and deleting the branch.</li>
            <li>If both tag and GitHub release have already been created, please close this task already.</li>
          </ul><br>
          Issue the following git commands to tag the release and delete the branch:
          <ul>
            <li><code>git fetch origin</code></li>
            <li><code>git checkout release/1.1.0</code> switch to the release branch</li>
            <li><code>git pull origin release/1.1.0</code> pull latest changes</li>
            <li><code>git tag 1.1.0-123</code> tag the release</li>
            <li><code>git push origin 1.1.0-123</code> push the tag</li>
            <li><code>git checkout main</code> switch to main</li>
            <li><code>git push origin --delete release/1.1.0</code> delete the release branch</li>
          </ul><br>
          To create GitHub release:
          <ul>
            <li>Set up GH CLI if you haven't yet: <a data-asana-gid='1203791243007683'/></li>
            <li>Run the following command:
            <ul>
              <li><code>gh release create 1.1.0-123 --generate-notes --latest --notes-start-tag 1.0.0</code></li>
            </ul></li>
          </ul><br>
          Complete this task when ready.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("public-release-tag-failed", {
        "branch" => "release/1.1.0",
        "tag" => "1.1.0-123",
        "base_branch" => "main",
        "last_release_tag" => "1.0.0",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes run-publish-dmg-release template" do
      expected_name = "Run Publish DMG Release GitHub Actions workflow"
      expected_notes = <<~EXPECTED
        <body>
          <h1>Using GH CLI</h1>
          Run the following command:<br>
          <br>
          <code>gh workflow run publish_dmg_release.yml --ref release/1.1.0 -f asana-task-url=https://app.asana.com/0/0/12345/f -f tag=1.1.0-123 -f release-type=internal</code>
          <h1>Using GitHub web UI</h1>
          <ol>
            <li>Open <a href='https://github.com/duckduckgo/apple-browsers/actions/workflows/macos_publish_dmg_release.yml'>Publish DMG Release workflow page</a>.</li>
            <li>Click "Run Workflow" and fill in the form as follows:
              <ul>
                <li><b>Branch</b> <code>release/1.1.0</code></li>
                <li><b>Asana release task URL</b> <code>https://app.asana.com/0/0/12345/f</code></li>
                <li><b>Tag to publish</b> <code>1.1.0-123</code></li>
                <li><b>Release Type</b> <code>internal</code></li>
              </ul></li>
          </ol><br>
          The GitHub Action workflow does the following:
          <ul>
            <li>Fetches the release DMG from staticcdn.duckduckgo.com</li>
            <li>Extracts release notes from the Asana task description</li>
            <li>Runs <code>appcastManager</code> to generate the new appcast2.xml file</li>
            <li>Stores the diff against previous version and the copy of the old appcast2.xml file</li>
            <li>Uploads new appcast, DMG and binary delta files to S3</li>
            <li>On success, creates a task for the release DRI to validate that "Check for Updates" works, with instructions on how to revert that change if "Check for Updates" is broken.</li>
            <li>On failure, creates a task for the release DRI with manual instructions on generating the appcast and uploading to S3.</li>
          </ul><br>
          Complete this task when ready and proceed with testing the build. If GitHub Actions is unavailable, you'll find manual instructions in the <em>Run Publish DMG Release GitHub Actions workflow</em> subtask of <em>Make Internal Release</em> task.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("run-publish-dmg-release", {
        "branch" => "release/1.1.0",
        "asana_task_url" => "https://app.asana.com/0/0/12345/f",
        "tag" => "1.1.0-123",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes update-asana-for-public-release template" do
      expected_name = "Move release task and included items to \"Done\" section in macOS App Board and close them if possible"
      expected_notes = <<~EXPECTED
        <body>
          Automation failed to update Asana for the public release. Please follow the steps below.
          <ol>
            <li>Open <a data-asana-gid='1234567890'/> and select the List view</li>
            <li>Scroll to the "Validation" section.</li>
            <li>Select all the tasks in that section.</li>
            <li>Drag and drop all the selected tasks to the "Done" section</li>
            <li>Close all tasks that are not incidents and don't belong to <a data-asana-gid='72649045549333'/> project, including the release task itself.</li>
          </ol><br>
          Complete this task when ready.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("update-asana-for-public-release", {
        "app_board_asana_project_id" => "1234567890",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes validate-check-for-updates-internal template" do
      expected_name = "Validate that 'Check For Updates' upgrades to 1.1.0 for internal users"
      expected_notes = <<~EXPECTED
        <body>
          <h1>Build 1.1.0 has been released internally via Sparkle 🎉</h1>
          Please verify that "Check for Updates" works correctly:
          <ol>
            <li>Launch a debug version of the app with an old version number.</li>
            <li>Identify as an internal user in the app.</li>
            <li>Go to Main Menu → DuckDuckGo → Check for Updates...</li>
            <li>Verify that you're being offered to update to 1.1.0.</li>
            <li>Verify that the update works.</li>
          </ol>
          <h1>🚨In case "Check for Updates" is broken</h1>
          You can restore previous version of the appcast2.xml:
          <ol>
            <li>Download the appcast-1.0.0.xml file attached to this task.</li>
            <li>Log in to AWS session:
              <ul>
                <li><code>aws --profile ddg-macos sso login</code></li>
              </ul></li>
            <li>Overwrite appcast2.xml with the old version:
              <ul>
                <li><code>aws --profile ddg-macos s3 cp appcast-1.0.0.xml s3://duckduckgo-releases/macos-browser/appcast2.xml --acl public-read</code></li>
              </ul></li>
          </ol><br>
          <hr>
          <h1>Summary of automated changes</h1>
          <h2>Changes to appcast2.xml</h2>
          See the attached <em>appcast-1.1.0-123.patch</em> file.
          <h2>Release notes</h2>
          See the attached <em>release-notes.txt</em> file for release notes extracted automatically from <a data-asana-gid='12345' data-asana-dynamic='false'>the release task</a> description.
          <h2>List of files uploaded to S3</h2>
          <ol>
            <li>appcast-1.1.0-123.xml</li><li>duckduckgo-1.1.0-123.dmg</li><li>duckduckgo-1.1.0-123.delta</li>
          </ol><br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("validate-check-for-updates-internal", {
        "tag" => "1.1.0",
        "old_appcast_name" => "appcast-1.0.0.xml",
        "release_bucket_name" => "duckduckgo-releases",
        "release_bucket_prefix" => "macos-browser",
        "appcast_patch_name" => "appcast-1.1.0-123.patch",
        "release_notes_file" => "release-notes.txt",
        "release_task_id" => "12345",
        "files_uploaded" => "<li>appcast-1.1.0-123.xml</li><li>duckduckgo-1.1.0-123.dmg</li><li>duckduckgo-1.1.0-123.delta</li>",
        "workflow_url" => "https://workflow.com"
      })

      expect(name).to eq(expected_name)
      expect(notes).to eq(expected_notes)
    end

    it "processes validate-check-for-updates-public template" do
      expected_name = "Validate that 'Check For Updates' upgrades to 1.1.0"
      expected_notes = <<~EXPECTED
        <body>
          <h1>Build 1.1.0 has been released publicly via Sparkle 🎉</h1>
          Please verify that "Check for Updates" works correctly:
          <ol>
            <li>Launch a debug version of the app with an old version number.</li>
            <li>Make sure you're not identified as an internal user in the app.</li>
            <li>Go to Main Menu → DuckDuckGo → Check for Updates...</li>
            <li>Verify that you're being offered to update to 1.1.0.</li>
            <li>Verify that the update works.</li>
          </ol>
          <h1>🚨In case "Check for Updates" is broken</h1>
          You can restore previous version of the appcast2.xml:
          <ol>
            <li>Download the appcast-1.0.0.xml file attached to this task.</li>
            <li>Log in to AWS session:
              <ul>
                <li><code>aws --profile ddg-macos sso login</code></li>
              </ul></li>
            <li>Overwrite appcast2.xml with the old version:
              <ul>
                <li><code>aws --profile ddg-macos s3 cp appcast-1.0.0.xml s3://duckduckgo-releases/macos-browser/appcast2.xml --acl public-read</code></li>
              </ul></li>
          </ol><br>
          <hr>
          <h1>Summary of automated changes</h1>
          <h2>Changes to appcast2.xml</h2>
          See the attached <em>appcast-1.1.0-123.patch</em> file.
          <h2>Release notes</h2>
          See the attached <em>release-notes.txt</em> file for release notes extracted automatically from <a data-asana-gid='12345' data-asana-dynamic='false'>the release task</a> description.
          <h2>List of files uploaded to S3</h2>
          <ol>
            <li>appcast-1.1.0-123.xml</li><li>duckduckgo-1.1.0-123.dmg</li><li>duckduckgo-1.1.0-123.delta</li>
          </ol><br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      name, notes = process_yaml_template("validate-check-for-updates-public", {
        "tag" => "1.1.0",
        "old_appcast_name" => "appcast-1.0.0.xml",
        "release_bucket_name" => "duckduckgo-releases",
        "release_bucket_prefix" => "macos-browser",
        "appcast_patch_name" => "appcast-1.1.0-123.patch",
        "release_notes_file" => "release-notes.txt",
        "release_task_id" => "12345",
        "files_uploaded" => "<li>appcast-1.1.0-123.xml</li><li>duckduckgo-1.1.0-123.dmg</li><li>duckduckgo-1.1.0-123.delta</li>",
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
