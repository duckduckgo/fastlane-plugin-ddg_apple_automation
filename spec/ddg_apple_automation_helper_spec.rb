require "climate_control"

describe Fastlane::Helper::DdgAppleAutomationHelper do
  describe "#asana_task_url" do
    it "constructs Asana task URL" do
      expect(asana_task_url("1234567890")).to eq("https://app.asana.com/0/0/1234567890/f")
      expect(asana_task_url("0")).to eq("https://app.asana.com/0/0/0/f")
    end

    it "shows error when task_id is empty" do
      allow(Fastlane::UI).to receive(:user_error!)
      asana_task_url("")
      expect(Fastlane::UI).to have_received(:user_error!).with("Task ID cannot be empty")
    end

    def asana_task_url(task_id)
      Fastlane::Helper::DdgAppleAutomationHelper.asana_task_url(task_id)
    end
  end

  describe "#extract_asana_task_id" do
    it "extracts task ID" do
      expect(extract_asana_task_id("https://app.asana.com/0/0/0")).to eq("0")
    end

    it "extracts task ID when project ID is non-zero" do
      expect(extract_asana_task_id("https://app.asana.com/0/753241/9999")).to eq("9999")
    end

    it "extracts task ID when first digit is non-zero" do
      expect(extract_asana_task_id("https://app.asana.com/4/753241/9999")).to eq("9999")
    end

    it "extracts long task ID" do
      expect(extract_asana_task_id("https://app.asana.com/0/0/12837864576817392")).to eq("12837864576817392")
    end

    it "extracts task ID from a URL with a trailing /f" do
      expect(extract_asana_task_id("https://app.asana.com/0/0/1234/f")).to eq("1234")
    end

    it "sets GHA output" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(extract_asana_task_id("https://app.asana.com/0/12837864576817392/3465387322")).to eq("3465387322")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_task_id", "3465387322")
    end

    it "fails when garbage is passed" do
      expect(Fastlane::UI).to receive(:user_error!)
        .with("URL has incorrect format (attempted to match #{Fastlane::Helper::DdgAppleAutomationHelper::ASANA_TASK_URL_REGEX})")

      extract_asana_task_id("not a URL")
    end

    def extract_asana_task_id(task_url)
      Fastlane::Helper::DdgAppleAutomationHelper.extract_asana_task_id(task_url)
    end
  end

  describe "#extract_asana_task_assignee" do
    before do
      @asana_client_tasks = double
      asana_client = double("asana_client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)
      allow(@asana_client_tasks).to receive(:get_task)
    end

    it "returns the assignee ID and sets GHA output when Asana task is assigned" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      expect(@asana_client_tasks).to receive(:get_task).and_return(
        double(assignee: { "gid" => "67890" })
      )

      expect(extract_asana_task_assignee("12345")).to eq("67890")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_assignee_id", "67890")
    end

    it "returns nil when Asana task is not assigned" do
      expect(@asana_client_tasks).to receive(:get_task).and_return(
        double(assignee: { "gid" => nil })
      )

      expect(extract_asana_task_assignee("12345")).to eq(nil)
    end

    it "shows error when failed to fetch task assignee" do
      expect(@asana_client_tasks).to receive(:get_task).and_raise(StandardError, "API error")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to fetch task assignee: API error")

      extract_asana_task_assignee("12345")
    end

    def extract_asana_task_assignee(task_id)
      Fastlane::Helper::DdgAppleAutomationHelper.extract_asana_task_assignee(task_id, anything)
    end
  end

  describe "#get_release_automation_subtask_id" do
    before do
      @asana_client_tasks = double
      asana_client = double("asana_client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)
      allow(@asana_client_tasks).to receive(:get_subtasks_for_task)
    end
    it "returns the 'Automation' subtask ID and sets GHA output when the subtask exists in the Asana task" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:extract_asana_task_assignee)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_return(
        [double(gid: "12345", name: "Automation", created_at: "2020-01-01T00:00:00.000Z")]
      )

      expect(get_release_automation_subtask_id("https://app.asana.com/0/0/0")).to eq("12345")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_automation_task_id", "12345")
    end

    it "returns the oldest 'Automation' subtask when there are multiple subtasks with that name" do
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:extract_asana_task_assignee)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_return(
        [double(gid: "12345", name: "Automation", created_at: "2020-01-01T00:00:00.000Z"),
         double(gid: "431", name: "Automation", created_at: "2019-01-01T00:00:00.000Z"),
         double(gid: "12460", name: "Automation", created_at: "2020-01-05T00:00:00.000Z")]
      )

      expect(get_release_automation_subtask_id("https://app.asana.com/0/0/0")).to eq("431")
    end

    it "returns nil when 'Automation' subtask does not exist in the Asana task" do
      allow(Fastlane::UI).to receive(:user_error!)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:extract_asana_task_assignee)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_raise(StandardError, "API error")

      get_release_automation_subtask_id("https://app.asana.com/0/0/0")
      expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch 'Automation' subtasks for task 0: API error")
    end

    def get_release_automation_subtask_id(task_url)
      Fastlane::Helper::DdgAppleAutomationHelper.get_release_automation_subtask_id(task_url, anything)
    end
  end

  describe "#get_asana_user_id_for_github_handle" do
    let(:yaml_content) do
      {
        "duck" => "123",
        "goose" => "456",
        "pigeon" => nil,
        "hawk" => ""
      }
    end

    before do
      allow(YAML).to receive(:load_file).and_return(yaml_content)
    end

    it "sets the user ID output and GHA output correctly" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(get_asana_user_id_for_github_handle("duck")).to eq("123")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_user_id", "123")
    end

    it "shows warning when handle does not exist" do
      expect(Fastlane::UI).to receive(:message).with("Asana User ID not found for GitHub handle: chicken")
      get_asana_user_id_for_github_handle("chicken")
    end

    it "shows warning when handle is nil" do
      expect(Fastlane::UI).to receive(:message).with("Asana User ID not found for GitHub handle: pigeon")
      get_asana_user_id_for_github_handle("pigeon")
    end

    it "shows warning when handle is empty" do
      expect(Fastlane::UI).to receive(:message).with("Asana User ID not found for GitHub handle: hawk")
      get_asana_user_id_for_github_handle("hawk")
    end

    def get_asana_user_id_for_github_handle(github_handle)
      Fastlane::Helper::DdgAppleAutomationHelper.get_asana_user_id_for_github_handle(github_handle)
    end
  end

  describe "#load_file" do
    it "shows error if provided file does not exist" do
      allow(Fastlane::UI).to receive(:user_error!)
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      load_file("file")
      expect(Fastlane::UI).to have_received(:user_error!).with("Error: The file 'file' does not exist.")
    end

    def load_file(file)
      Fastlane::Helper::DdgAppleAutomationHelper.load_file(file)
    end
  end

  describe "#sanitize_asana_html_notes" do
    it "removes newlines and leading/trailing spaces" do
      content = "   \nHello, \n\n World!\n This is a test.   \n"
      expect(sanitize_asana_html_notes(content)).to eq("Hello, World! This is a test.")
    end

    it "removes spaces between html tags" do
      content = "<body> <h2>Hello, World! This is a test.</h2> </body>"
      expect(sanitize_asana_html_notes(content)).to eq("<body><h2>Hello, World! This is a test.</h2></body>")
    end

    it "replaces multiple whitespaces with a single space" do
      content = "<h2>Hello,   World! This   is a test.</h2>"
      expect(sanitize_asana_html_notes(content)).to eq("<h2>Hello, World! This is a test.</h2>")
    end

    it "replaces <br> tags with new lines" do
      content = "<h2>Hello, World!<br> This is a test.</h2>"
      expect(sanitize_asana_html_notes(content)).to eq("<h2>Hello, World!\n This is a test.</h2>")
    end

    it "preserves HTML-escaped characters" do
      content = "<body>Hello -&gt; World!</body>"
      expect(sanitize_asana_html_notes(content)).to eq("<body>Hello -&gt; World!</body>")
    end

    def sanitize_asana_html_notes(content)
      Fastlane::Helper::DdgAppleAutomationHelper.sanitize_asana_html_notes(content)
    end
  end
end
