describe Fastlane::Actions::AsanaReportFailedWorkflowAction do
  describe "#run" do
    subject { Fastlane::Actions::AsanaReportFailedWorkflowAction.run(params) }
    let (:params) do
      {
        asana_access_token: "asana-token",
        github_token: "github-token",
        is_scheduled_release: false,
        platform: "ios",
        task_id: "1234567890",
        branch: "release/ios/1.0.0",
        commit_sha: "abc123",
        github_handle: "user",
        workflow_name: "sample workflow",
        workflow_url: "https://workflow.com"
      }
    end
    let (:assignee_id) { "123" }
    let (:last_commit_author_id) { "456" }
    let (:workflow_actor_id) { "789" }

    before do
      commit_author = "committer"
      allow(Fastlane::Helper::GitHelper).to receive(:commit_author).and_return(commit_author)
      allow(Fastlane::Helper::AsanaHelper).to receive(:get_asana_user_id_for_github_handle).with(commit_author).and_return(last_commit_author_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:get_asana_user_id_for_github_handle).with(params[:github_handle]).and_return(workflow_actor_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee).and_return(assignee_id)
      allow(Fastlane::Actions::AsanaReportFailedWorkflowAction).to receive(:add_collaborators)
      allow(Fastlane::UI).to receive(:important)
      allow(Fastlane::Actions::AsanaAddCommentAction).to receive(:run)
    end

    it "reports failed workflow" do
      subject
      expect(Fastlane::Helper::GitHelper).to have_received(:commit_author).with(anything, "abc123", "github-token")
      expect(Fastlane::Helper::AsanaHelper).to have_received(:get_asana_user_id_for_github_handle).with("committer")
      expect(Fastlane::Helper::AsanaHelper).to have_received(:extract_asana_task_assignee).with("1234567890", "asana-token")
      expect(Fastlane::Actions::AsanaReportFailedWorkflowAction).to have_received(:add_collaborators).with(anything, "1234567890", "asana-token")
      expect(Fastlane::Actions::AsanaAddCommentAction).to have_received(:run).with(
        task_id: "1234567890",
        template_name: "workflow-failed",
        template_args: {
          assignee_id: assignee_id,
          last_commit_author_id: last_commit_author_id,
          last_commit_url: "https://github.com/duckduckgo/apple-browsers/commit/abc123",
          workflow_actor_id: "789",
          workflow_name: "sample workflow",
          workflow_url: "https://workflow.com"
        },
        asana_access_token: "asana-token"
      )
    end

    context "when is scheduled release" do
      before do
        params[:is_scheduled_release] = true
      end

      it "reports failed workflow without workflow_actor_id" do
        subject
        expect(Fastlane::Actions::AsanaAddCommentAction).to have_received(:run).with(
          hash_including(template_args: hash_excluding(:workflow_actor_id))
        )
      end
    end

    context "when commit_sha is not provided" do
      before do
        params.delete(:commit_sha)
      end

      it "reports failed workflow without last_commit_author_id and last_commit_url" do
        subject
        expect(Fastlane::Actions::AsanaAddCommentAction).to have_received(:run).with(
          hash_including(template_args: hash_excluding(:last_commit_author_id, :last_commit_url))
        )
      end
    end

    shared_examples "skipping cc assignee" do
      it "reports failed workflow without explicitly cc-ing the assignee" do
        subject
        expect(Fastlane::Actions::AsanaAddCommentAction).to have_received(:run).with(
          hash_including(template_args: hash_excluding(:assignee_id))
        )
      end
    end

    context "when workflow is triggered by task assignee" do
      let (:workflow_actor_id) { assignee_id }

      it_behaves_like "skipping cc assignee"
    end

    context "when last commit is made by task assignee" do
      let (:last_commit_author_id) { assignee_id }

      it_behaves_like "skipping cc assignee"
    end
  end

  describe "#add_collaborators" do
    subject { Fastlane::Actions::AsanaReportFailedWorkflowAction.add_collaborators(collaborators, task_id, asana_access_token) }

    let (:collaborators) { ["123", "456"] }
    let (:task_id) { "1234567890" }
    let (:asana_access_token) { "asana-token" }
    let (:asana_client) { double(tasks: double(add_followers_for_task: nil)) }

    before do
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(asana_client)
      allow(Fastlane::UI).to receive(:important)
      allow(asana_client).to receive(:tasks).with(task_gid: task_id, followers: collaborators)
      allow(Fastlane::UI).to receive(:user_error!)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:report_error)
    end

    it "adds collaborators to the task" do
      subject
      expect(Fastlane::Helper::AsanaHelper).to have_received(:make_asana_client).with("asana-token")
      expect(asana_client.tasks).to have_received(:add_followers_for_task).with(task_gid: "1234567890", followers: ["123", "456"])
    end

    context "when there are no collaborators" do
      let (:collaborators) { [] }

      it "does nothing if there are no collaborators" do
        subject
        expect(Fastlane::Helper::AsanaHelper).not_to have_received(:make_asana_client)
        expect(asana_client).not_to have_received(:tasks)
        expect(Fastlane::UI).not_to have_received(:important)
        expect(Fastlane::UI).not_to have_received(:user_error!)
        expect(Fastlane::Helper::DdgAppleAutomationHelper).not_to have_received(:report_error)
      end
    end

    context "when adding collaborators fails" do
      before do
        allow(asana_client.tasks).to receive(:add_followers_for_task).and_raise(StandardError)
      end

      it "reports an error" do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:make_asana_client).with("asana-token")
        expect(asana_client.tasks).to have_received(:add_followers_for_task).with(task_gid: "1234567890", followers: ["123", "456"])

        expect(Fastlane::UI).to have_received(:user_error!)
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:report_error).with(StandardError)
      end
    end
  end
end