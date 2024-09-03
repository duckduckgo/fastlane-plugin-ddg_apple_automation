require "climate_control"

describe Fastlane::Actions::AsanaAddCommentAction do
  describe "#run" do
    it "does not call task id extraction if task id provided" do
      allow(HTTParty).to receive(:post).and_return(double(success?: true))
      expect(Fastlane::Actions::AsanaExtractTaskIdAction).not_to receive(:run)
      test_action(task_id: "123", comment: "", workflow_url: "")
    end

    it "extracts task id if task id not provided" do
      allow(HTTParty).to receive(:post).and_return(double(success?: true))
      expect(Fastlane::Actions::AsanaExtractTaskIdAction).to receive(:run)
        .and_return("9999")
      test_action(task_url: "https://app.asana.com/0/753241/9999", comment: "", workflow_url: "")
    end

    it "shows error if both task id and task url are not provided" do
      expect(Fastlane::UI).to receive(:user_error!).with("Both task_id and task_url cannot be nil. At least one must be provided.")
      test_action
    end

    it "shows error if both comment and template_name are not provided" do
      expect(Fastlane::UI).to receive(:user_error!).with("Both comment and template_name cannot be nil. At least one must be provided.")
      test_action(task_id: "123")
    end

    it "shows error if comment is provided but workflow_url is not" do
      expect(Fastlane::UI).to receive(:user_error!).with("If comment is provided, workflow_url cannot be nil")
      test_action(task_id: "123", comment: "")
    end

    it "shows error if provided template does not exist" do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      expect(Fastlane::UI).to receive(:user_error!).with("Error: The file 'non-existing.yml' does not exist.")
      test_action(task_id: "123", template_name: "non-existing")
    end

    it "shows error if provided template does not exist" do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      expect(Fastlane::UI).to receive(:user_error!).with("Error: The file 'non-existing.yml' does not exist.")
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
      template_content = "   \nHello, \n  World!\n   This is a test.   \n"
      result = Fastlane::Actions::AsanaAddCommentAction.process_template_content(template_content)
      expect(result).to eq("Hello, World! This is a test.")
    end

    it "converts to json and encodes with base64" do
      result = Fastlane::Actions::AsanaAddCommentAction.convert_to_json_and_encode_Base64("Hello world!")
      expect(result).to eq("IkhlbGxvIHdvcmxkISI=")
    end

    it "correctly builds comment payload" do
      comment = "This is a test comment."
      workflow_url = "http://github.com/duckduckgo/iOS/actions/runs/123"
      result = Fastlane::Actions::AsanaAddCommentAction.process_comment(comment, workflow_url)
      expect(result).to eq({ 'data' => { 'text' => "This is a test comment.\n\nWorkflow URL: http://github.com/duckduckgo/iOS/actions/runs/123" } })
    end

    it "does not raise any error if comment is posted successfully" do
      expect(HTTParty).to receive(:post).and_return(double(success?: true))
      test_action(task_id: "123", comment: "", workflow_url: "")
    end
  end

  def test_action(task_id: nil, task_url: nil, comment: nil, template_name: nil, workflow_url: nil)
    Fastlane::Actions::AsanaAddCommentAction.run(task_id: task_id,
                                                 task_url: task_url,
                                                 comment: comment,
                                                 template_name: template_name,
                                                 workflow_url: workflow_url)
  end
end
