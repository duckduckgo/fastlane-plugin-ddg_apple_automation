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
