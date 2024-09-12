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

  describe "#sanitize_html_and_replace_env_vars" do
    it "substitutes all env variables" do
      content = "<h2>${ASSIGNEE_ID} is publishing ${TAG} hotfix release</h2>"
      ClimateControl.modify(
        ASSIGNEE_ID: '12345',
        TAG: 'v1.0.0'
      ) do
        expect(sanitize_html_and_replace_env_vars(content)).to eq("<h2>12345 is publishing v1.0.0 hotfix release</h2>")
      end
    end

    it "removes newlines and leading/trailing spaces" do
      content = "   \nHello, \n\n World!\n This is a test.   \n"
      expect(sanitize_html_and_replace_env_vars(content)).to eq("Hello, World! This is a test.")
    end

    it "removes spaces between html tags" do
      content = "<body> <h2>Hello, World! This is a test.</h2> </body>"
      expect(sanitize_html_and_replace_env_vars(content)).to eq("<body><h2>Hello, World! This is a test.</h2></body>")
    end

    it "replaces multiple whitespaces with a single space" do
      content = "<h2>Hello,   World! This   is a test.</h2>"
      expect(sanitize_html_and_replace_env_vars(content)).to eq("<h2>Hello, World! This is a test.</h2>")
    end

    it "replaces <br> tags with new lines" do
      content = "<h2>Hello, World!<br> This is a test.</h2>"
      expect(sanitize_html_and_replace_env_vars(content)).to eq("<h2>Hello, World!\n This is a test.</h2>")
    end

    it "preserves HTML-escaped characters" do
      content = "<body>Hello -&gt; World!</body>"
      expect(sanitize_html_and_replace_env_vars(content)).to eq("<body>Hello -&gt; World!</body>")
    end

    def sanitize_html_and_replace_env_vars(content)
      Fastlane::Helper::DdgAppleAutomationHelper.sanitize_html_and_replace_env_vars(content)
    end
  end
end
