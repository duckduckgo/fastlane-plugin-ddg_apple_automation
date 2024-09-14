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
end
