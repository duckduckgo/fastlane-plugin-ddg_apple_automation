describe Fastlane::Actions::AsanaLogMessageAction do
  describe "#run" do
    let(:task_url) { "https://example.com" }
    let(:task_id) { "1" }
    let(:automation_subtask_id) { "2" }
    let(:assignee_id) { "11" }
    let(:comment) { "comment" }
    let(:github_handle) { "user" }

    before do
      @asana_client_tasks = double
      asana_client = double("Asana::Client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)

      allow(Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction).to receive(:run).and_return(automation_subtask_id)
      allow(Fastlane::Actions::AsanaExtractTaskIdAction).to receive(:run).and_return(task_id)
      allow(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run).and_return(assignee_id)
      allow(Fastlane::Actions::AsanaGetUserIdForGithubHandleAction).to receive(:run).and_return(assignee_id)
      allow(@asana_client_tasks).to receive(:add_followers_for_task)
      allow(Fastlane::Actions::AsanaAddCommentAction).to receive(:run)
    end

    it "extracts assignee id from release task when is scheduled release" do
      expect(Fastlane::Actions::AsanaExtractTaskIdAction).to receive(:run).with(task_url: task_url)
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run).with(
        task_id: task_id,
        asana_access_token: anything
      )
      test_action(task_url: task_url, comment: comment, is_scheduled_release: true)
    end

    it "takes assignee id from github handle when is manual release" do
      expect(Fastlane::Actions::AsanaGetUserIdForGithubHandleAction).to receive(:run).with(
        github_handle: github_handle,
        asana_access_token: anything
      )
      test_action(task_url: task_url, comment: comment, is_scheduled_release: false, github_handle: github_handle)
    end

    it "raises an error when github handle is empty and is manual release" do
      expect(Fastlane::UI).to receive(:user_error!).with("Github handle cannot be empty for manual release")
      test_action(task_url: task_url, comment: comment, is_scheduled_release: false, github_handle: "")
    end

    it "adds an assignee as follower to the automation task" do
      expect(@asana_client_tasks).to receive(:add_followers_for_task).with(task_gid: automation_subtask_id, followers: [assignee_id])
      test_action(task_url: task_url, comment: comment, is_scheduled_release: false, github_handle: github_handle)
    end

    it "raises an error if adding a collaborator fails" do
      allow(Fastlane::UI).to receive(:user_error!)
      allow(@asana_client_tasks).to receive(:add_followers_for_task).and_raise(StandardError, 'some error')
      test_action(task_url: task_url, comment: comment, is_scheduled_release: false, github_handle: github_handle)
      expect(Fastlane::UI).to have_received(:user_error!).with("Failed to add user 11 as collaborator on task 2: some error")
    end

    it "adds a comment to the automation subtask" do
      expect(Fastlane::Actions::AsanaAddCommentAction).to receive(:run).with(
        task_id: automation_subtask_id,
        comment: comment,
        template_name: nil,
        asana_access_token: anything
      )
      test_action(task_url: task_url, comment: comment, is_scheduled_release: false, github_handle: github_handle)
    end
  end

  def test_action(task_url:, github_handle: nil, comment: nil, template_name: nil, is_scheduled_release: false)
    Fastlane::Actions::AsanaLogMessageAction.run(task_url: task_url,
                                                 comment: comment,
                                                 template_name: template_name,
                                                 is_scheduled_release: is_scheduled_release,
                                                 github_handle: github_handle)
  end
end
