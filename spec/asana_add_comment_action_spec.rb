require "climate_control"

describe Fastlane::Actions::AsanaAddCommentAction do
  describe "#run" do
    before do
      @asana_client_stories = double
      asana_client = double("Asana::Client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:stories).and_return(@asana_client_stories)

      ENV["WORKFLOW_URL"] = "http://www.example.com"
    end

    it "does not call task id extraction if task id provided" do
      allow(Fastlane::Actions::AsanaExtractTaskIdAction).to receive(:run)
      allow(@asana_client_stories).to receive(:create_story_for_task).and_return(double)
      test_action(task_id: "123", comment: "comment")
      expect(Fastlane::Actions::AsanaExtractTaskIdAction).not_to have_received(:run)
    end

    it "extracts task id if task id not provided" do
      allow(@asana_client_stories).to receive(:create_story_for_task).and_return(double)
      allow(Fastlane::Actions::AsanaExtractTaskIdAction).to receive(:run)
      test_action(task_url: "https://app.asana.com/0/753241/9999", comment: "comment")
      expect(Fastlane::Actions::AsanaExtractTaskIdAction).to have_received(:run).with(
        task_url: "https://app.asana.com/0/753241/9999"
      )
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
        WORKFLOW_URL: ''
      ) do
        expect(Fastlane::UI).to receive(:user_error!).with("If comment is provided, workflow_url cannot be empty")
        test_action(task_id: "123", comment: "comment")
      end
    end

    it "shows error if provided template does not exist" do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:path_for_asset_file).and_return("non-existing.html")
      expect(Fastlane::UI).to receive(:user_error!).with("Error: The file 'non-existing.html' does not exist.")
      expect(@asana_client_stories).not_to receive(:create_story_for_task)
      test_action(task_id: "123", template_name: "non-existing")
    end

    it "correctly substitutes all variables" do
      template_content = "<h2>${ASSIGNEE_ID} is publishing ${TAG} hotfix release</h2>"
      ClimateControl.modify(
        ASSIGNEE_ID: '12345',
        TAG: 'v1.0.0'
      ) do
        result = Fastlane::Actions::AsanaAddCommentAction.process_template_content(template_content)
        expected_output = "<h2>12345 is publishing v1.0.0 hotfix release</h2>"
        expect(result).to eq(expected_output)
      end
    end

    it "removes newlines and leading/trailing spaces" do
      template_content = "   \nHello, \n\n  World!\n   This is a test.   \n"
      result = Fastlane::Actions::AsanaAddCommentAction.process_template_content(template_content)
      expect(result).to eq("Hello, World! This is a test.")
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
        WORKFLOW_URL: "http://github.com/duckduckgo/iOS/actions/runs/123"
      ) do
        test_action(task_id: "123", comment: "This is a test comment.")
      end
      expect(@asana_client_stories).to have_received(:create_story_for_task).with(
        task_gid: "123",
        text: "This is a test comment.\n\nWorkflow URL: http://github.com/duckduckgo/iOS/actions/runs/123"
      )
    end

    it "fails when client raises error" do
      allow(@asana_client_stories).to receive(:create_story_for_task).and_raise(StandardError, "API error")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to post comment: API error")
      test_action(task_id: "123", comment: "comment")
    end
  end

  def test_action(task_id: nil, task_url: nil, comment: nil, template_name: nil, workflow_url: nil)
    Fastlane::Actions::AsanaAddCommentAction.run(task_id: task_id,
                                                 task_url: task_url,
                                                 comment: comment,
                                                 template_name: template_name)
  end
end