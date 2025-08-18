require "climate_control"

describe Fastlane::Actions::AsanaAddCommentAction do
  describe "#run" do
    before do
      @asana_client_stories = double
      asana_client = double("Asana::Client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:stories).and_return(@asana_client_stories)

      ENV["workflow_url"] = "http://www.example.com"
    end

    it "does not call task id extraction if task id provided" do
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_id)
      allow(@asana_client_stories).to receive(:create_story_for_task).and_return(double)
      test_action(task_id: "123", comment: "comment")
      expect(Fastlane::Helper::AsanaHelper).not_to have_received(:extract_asana_task_id)
    end

    it "extracts task id if task id not provided" do
      allow(@asana_client_stories).to receive(:create_story_for_task).and_return(double)
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_id)
      test_action(task_url: "https://app.asana.com/0/753241/9999", comment: "comment")
      expect(Fastlane::Helper::AsanaHelper).to have_received(:extract_asana_task_id).with("https://app.asana.com/0/753241/9999")
    end

    it "shows error if both task id and task url are not provided" do
      expect(Fastlane::UI).to receive(:user_error!).with("Both task_id and task_url cannot be empty. At least one must be provided.")
      test_action
    end

    it "shows error if both comment and template_name are not provided" do
      expect(Fastlane::UI).to receive(:user_error!).with("Both comment and template_name cannot be empty. At least one must be provided.")
      test_action(task_id: "123")
    end

    it "shows error if comment is provided but workflow_url is not" do
      ClimateControl.modify(
        workflow_url: ''
      ) do
        expect(Fastlane::UI).to receive(:user_error!).with("If comment is provided, workflow_url cannot be empty")
        test_action(task_id: "123", comment: "comment")
      end
    end

    it "correctly builds html_text payload" do
      allow(File).to receive(:read).and_return("   \nHello, \n  World!\n   This is a test.   \n")
      allow(@asana_client_stories).to receive(:create_story_for_task)
      test_action(task_id: "123", template_name: "whatever")
      expect(@asana_client_stories).to have_received(:create_story_for_task).with(
        task_gid: "123",
        html_text: "Hello, World! This is a test."
      )
    end

    it "correctly builds text payload" do
      allow(@asana_client_stories).to receive(:create_story_for_task)
      ClimateControl.modify(
        WORKFLOW_URL: "http://github.com/duckduckgo/apple-browsers/actions/runs/123"
      ) do
        test_action(task_id: "123", comment: "This is a test comment.")
      end
      expect(@asana_client_stories).to have_received(:create_story_for_task).with(
        task_gid: "123",
        text: "This is a test comment.\n\nWorkflow URL: http://github.com/duckduckgo/apple-browsers/actions/runs/123"
      )
    end

    it "fails when client raises error" do
      allow(@asana_client_stories).to receive(:create_story_for_task).and_raise(StandardError, "API error")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to post comment: API error")
      test_action(task_id: "123", comment: "comment")
    end

    def test_action(task_id: nil, task_url: nil, comment: nil, template_name: nil, workflow_url: nil)
      Fastlane::Actions::AsanaAddCommentAction.run(task_id: task_id,
                                                   task_url: task_url,
                                                   comment: comment,
                                                   template_name: template_name)
    end
  end

  describe "#process_template" do
    it "processes appcast-failed-hotfix template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Publishing 1.0.0-123 hotfix release to Sparkle failed</h2>
          <a data-asana-gid='12345' />, please proceed with generating appcast2.xml and uploading files to S3 from your
          local machine, <a data-asana-gid='67890' data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("appcast-failed-hotfix", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes appcast-failed-internal template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Publishing 1.0.0-123 internal release to Sparkle failed</h2>
          <a data-asana-gid='12345' />, please proceed with generating appcast2.xml and uploading files to S3 from your
          local machine, <a data-asana-gid='67890' data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("appcast-failed-internal", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes appcast-failed-public template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Publishing 1.0.0-123 release to Sparkle failed</h2>
          <a data-asana-gid='12345' />, please proceed with generating appcast2.xml and uploading files to S3 from your
          local machine, <a data-asana-gid='67890' data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("appcast-failed-public", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes debug-symbols-uploaded template" do
      expected = <<~EXPECTED
        <body>
          🐛 Debug symbols archive for 1.0.0-123 build is uploaded to <code>s3://bucket/duckduckgo-1.0.0.123.dmg.dSYM.zip</code>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("debug-symbols-uploaded", {
        "tag" => "1.0.0-123",
        "dsym_s3_path" => "s3://bucket/duckduckgo-1.0.0.123.dmg.dSYM.zip",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes dmg-uploaded template" do
      expected = <<~EXPECTED
        <body>
          📥 DMG for 1.0.0-123 is available from <a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("dmg-uploaded", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes hotfix-branch-ready template" do
      expected = <<~EXPECTED
        <body>
          <h2>Hotfix branch hotfix/1.0.1 ready ⚙️</h2>
          <ul>
            <li>🔱 <code>hotfix/1.0.1</code> branch has been created off <code>1.0.0</code> tag.</li>
            <li>Point any pull requests with changes required for the hotfix release to that branch.</li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("hotfix-branch-ready", {
        "branch" => "hotfix/1.0.1",
        "release_tag" => "1.0.0",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes internal-release-complete-with-tasks template" do
      expected = <<~EXPECTED
        <body>
          Build 1.0.0-123 is now available for internal testing through Sparkle and TestFlight.<br>
          <br>
          Added in this release:
          <ul><li>Task 1</li><li>Task 2</li></ul><br>
          <br>
          <a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>📥 DMG download link</a>
        </body>
      EXPECTED

      expect(process_template("internal-release-complete-with-tasks", {
        "tag" => "1.0.0-123",
        "tasks_since_last_internal_release" => "<ul><li>Task 1</li><li>Task 2</li></ul>",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg"
      })).to eq(expected.chomp)
    end

    it "processes internal-release-complete template" do
      expected = <<~EXPECTED
        <body>
          Build 1.0.0-123 is now available for internal testing through Sparkle and TestFlight.<br>
          <br><a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>📥 DMG download link</a>
        </body>
      EXPECTED

      expect(process_template("internal-release-complete", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg"
      })).to eq(expected.chomp)
    end

    it "processes internal-release-ready-merge-failed template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Internal release build 1.0.0-123 ready</h2>
          <ul>
            <li>📥 DMG is available from <a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg</a>.</li>
            <li>🏷️ Repository is tagged with <code>1.0.0-123</code> tag.</li>
            <li>🚢 GitHub <a href='https://github.com/releases/tag/1.0.0-123'>1.0.0-123 pre-release</a> is created.</li>
            <li><b>❗️ Merging <code>1.0.0-123</code> tag to <code>main</code> failed.</b>
              <ul>
                <li><a data-asana-gid='12345' />, please proceed with manual merging <a data-asana-gid='67890'
                    data-asana-dynamic='false'>according to instructions</a>.</li>
              </ul>
            </li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("internal-release-ready-merge-failed", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg",
        "release_url" => "https://github.com/releases/tag/1.0.0-123",
        "branch" => "release/1.0.0",
        "base_branch" => "main",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes internal-release-ready-tag-failed template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Internal release build 1.0.0-123 ready</h2>
          <ul>
            <li>📥 DMG is available from <a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg</a>.</li>
            <li><b>❗️ Tagging repository failed.</b></li>
            <li><b>⚠️ GitHub release creation was skipped.</b></li>
            <li><b>⚠️ Merging <code>1.0.0-123</code> tag to <code>main</code> was skipped.</b></li>
          </ul>
          <a data-asana-gid='12345' />, please proceed with manual tagging and merging <a data-asana-gid='67890'
            data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("internal-release-ready-tag-failed", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg",
        "branch" => "release/1.0.0",
        "base_branch" => "main",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes internal-release-ready template" do
      expected = <<~EXPECTED
        <body>
          <h2>Internal release build 1.0.0-123 ready ✅</h2>
          <ul>
            <li>📥 DMG is available from <a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg</a>.
              <ul>
                <li>If this is a subsequent internal release (started by calling <em>Bump Internal Release</em> workflow), the
                  DMG will be automatically published to Sparkle in a few minutes. Sit tight.</li>
              </ul>
            </li>
            <li>🏷️ Repository is tagged with <code>1.0.0-123</code> tag.</li>
            <li>🚢 GitHub <a href='https://github.com/releases/tag/1.0.0-123'>1.0.0-123 pre-release</a> is created.</li>
            <li>🔱 <code>1.0.0-123</code> tag has been successfully merged to <code>main</code>.</li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("internal-release-ready", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg",
        "release_url" => "https://github.com/releases/tag/1.0.0-123",
        "branch" => "release/1.0.0",
        "base_branch" => "main",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes public-release-tag-failed template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Failed to publish 1.0.0-123 release – tagging failed</h2>
          <ul>
            <li><b>❗️ Tagging repository with 1.0.0-123 tag failed.</b></li>
            <li><b>⚠️ GitHub release creation was skipped.</b></li>
            <li><b>⚠️ Deleting <code>release/1.0.0</code> was skipped.</b></li>
          </ul>
          <br>
          <a data-asana-gid='12345' />, please proceed with the release <a data-asana-gid='67890'
            data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("public-release-tag-failed", {
        "tag" => "1.0.0-123",
        "branch" => "release/1.0.0",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes public-release-tagged-delete-branch-failed template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] Public release 1.0.0-123 tagged</h2>
          <ul>
            <li>🏷️ Repository is tagged with <code>1.0.0-123</code> tag.</li>
            <li>🚢 GitHub <a href='https://github.com/releases/tag/1.0.0-123'>1.0.0-123 release</a> is created.</li>
            <li><b>❗️ Deleting <code>release/1.0.0</code> failed.</b>
              <ul>
                <li><a data-asana-gid='12345' />, please proceed with deleting the branch manually <a
                    data-asana-gid='67890' data-asana-dynamic='false'>according to instructions</a>.</li>
              </ul>
            </li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("public-release-tagged-delete-branch-failed", {
        "tag" => "1.0.0-123",
        "release_url" => "https://github.com/releases/tag/1.0.0-123",
        "branch" => "release/1.0.0",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes public-release-tagged template" do
      expected = <<~EXPECTED
        <body>
          <h2>Public release 1.0.0-123 has been tagged ✅</h2>
          <ul>
            <li>📥 DMG is available from <a href='https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg'>https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg</a>.</li>
            <li>🏷️ Repository is tagged with <code>1.0.0-123</code> tag.</li>
            <li>🚢 GitHub <a href='https://github.com/releases/tag/1.0.0-123'>1.0.0-123 release</a> is created.</li>
            <li>🔱 <code>release/1.0.0</code> branch has been deleted.</li>
            <li>🚀 The relase will be published to Sparkle in a few minutes (you'll get notified).</li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("public-release-tagged", {
        "tag" => "1.0.0-123",
        "dmg_url" => "https://cdn.com/bucket/duckduckgo-1.0.0.123.dmg",
        "release_url" => "https://github.com/releases/tag/1.0.0-123",
        "branch" => "release/1.0.0",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes validate-check-for-updates-internal template" do
      expected = <<~EXPECTED
        <body>
          <h2>Build 1.0.0-123 is available for internal testing through Sparkle 🚀</h2>
          <ul>
            <li>🌟 New appcast file has been generated and uploaded to S3, together with binary delta files.</li>
            <li>👀 <a data-asana-gid='12345' />, please proceed by following instructions in <a
                data-asana-gid='67890' /> which concludes the internal release process.</li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("validate-check-for-updates-internal", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes validate-check-for-updates-public template" do
      expected = <<~EXPECTED
        <body>
          <h2>Build 1.0.0-123 is available publicly through Sparkle 🚀</h2>
          <ul>
            <li>🌟 New appcast file has been generated and uploaded to S3, together with binary delta files.</li>
            <li>👀 <a data-asana-gid='12345' />, please proceed by following instructions in <a
                data-asana-gid='67890' /> and <a data-asana-gid='99999' /> which concludes the release
              process.</li>
          </ul>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("validate-check-for-updates-public", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "announcement_task_id" => "99999",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes public-release-merge-failed-untagged-commits template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] 1.0.0-123 public release not tagged – automatic merge failed</h2>
          You've requested proceeding with public release despite untagged commits on the <code>release/1.0.0</code> branch,#{' '}
          but merging the commits to <code>main</code> failed.
          <ul>
            <li><b>❗️ Tagging the repository with 1.0.0-123 public release tag was aborted.</b></li>
            <li><b>⚠️ GitHub release wasn't created.</b></li>
            <li><b>⚠️ <code>release/1.0.0</code> branch wasn't deleted.</b></li>
          </ul>
          <br>
          <a data-asana-gid='12345' />, please follow instructions to merge branches manually and proceed with the release <a data-asana-gid='67890'
            data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("public-release-merge-failed-untagged-commits", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "untagged_commit_sha" => "123abc",
        "untagged_commit_url" => "https://github.com/duckduckgo/apple-browsers/commit/123abc",
        "branch" => "release/1.0.0",
        "base_branch" => "main",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    it "processes public-release-tag-failed-untagged-commits template" do
      expected = <<~EXPECTED
        <body>
          <h2>[ACTION NEEDED] 1.0.0-123 public release not tagged – unreleased commits found</h2>
          <ul>
            <li><b>❗️ Tagging the repository with 1.0.0-123 public release tag was aborted because untagged commits were found on the release/1.0.0 branch.</b></li>
            <li>Top commit is <a href='https://github.com/duckduckgo/apple-browsers/commit/123abc'><code>123abc</code></a>.</li>
            <li><b>⚠️ GitHub release wasn't created.</b></li>
            <li><b>⚠️ <code>release/1.0.0</code> branch wasn't deleted.</b></li>
          </ul>
          <br>
          <a data-asana-gid='12345' />, please follow instructions to remove untagged commits and proceed with the release <a data-asana-gid='67890'
            data-asana-dynamic='false'>according to instructions</a>.<br>
          <br>
          🔗 Workflow URL: <a href='https://workflow.com'>https://workflow.com</a>.
        </body>
      EXPECTED

      expect(process_template("public-release-tag-failed-untagged-commits", {
        "tag" => "1.0.0-123",
        "assignee_id" => "12345",
        "task_id" => "67890",
        "untagged_commit_sha" => "123abc",
        "untagged_commit_url" => "https://github.com/duckduckgo/apple-browsers/commit/123abc",
        "branch" => "release/1.0.0",
        "base_branch" => "main",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected.chomp)
    end

    def process_template(template_name, args)
      Fastlane::Actions::AsanaAddCommentAction.process_template(template_name, args)
    end
  end
end
