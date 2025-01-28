describe Fastlane::Helper::AsanaHelper do
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
      Fastlane::Helper::AsanaHelper.asana_task_url(task_id)
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
        .with("URL has incorrect format (attempted to match #{Fastlane::Helper::AsanaHelper::ASANA_TASK_URL_REGEX})")

      extract_asana_task_id("not a URL")
    end

    def extract_asana_task_id(task_url)
      Fastlane::Helper::AsanaHelper.extract_asana_task_id(task_url)
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
      Fastlane::Helper::AsanaHelper.extract_asana_task_assignee(task_id, anything)
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
      expect(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_return(
        [double(gid: "12345", name: "Automation", created_at: "2020-01-01T00:00:00.000Z")]
      )

      expect(get_release_automation_subtask_id("https://app.asana.com/0/0/0")).to eq("12345")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_automation_task_id", "12345")
    end

    it "returns the oldest 'Automation' subtask when there are multiple subtasks with that name" do
      expect(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_return(
        [double(gid: "12345", name: "Automation", created_at: "2020-01-01T00:00:00.000Z"),
         double(gid: "431", name: "Automation", created_at: "2019-01-01T00:00:00.000Z"),
         double(gid: "12460", name: "Automation", created_at: "2020-01-05T00:00:00.000Z")]
      )

      expect(get_release_automation_subtask_id("https://app.asana.com/0/0/0")).to eq("431")
    end

    it "returns nil when 'Automation' subtask does not exist in the Asana task" do
      allow(Fastlane::UI).to receive(:user_error!)
      expect(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_raise(StandardError, "API error")

      get_release_automation_subtask_id("https://app.asana.com/0/0/0")
      expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch 'Automation' subtasks for task 0: API error")
    end

    def get_release_automation_subtask_id(task_url)
      Fastlane::Helper::AsanaHelper.get_release_automation_subtask_id(task_url, anything)
    end
  end

  describe "#get_asana_user_id_for_github_handle" do
    it "sets the user ID output and GHA output correctly" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(get_asana_user_id_for_github_handle("jotaemepereira")).to eq("1203972458584419")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_user_id", "1203972458584419")
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
      Fastlane::Helper::AsanaHelper.get_asana_user_id_for_github_handle(github_handle)
    end
  end

  describe "#upload_file_to_asana_task" do
    before do
      @task = double("task")
      @asana_client_tasks = double("asana_client_tasks")
      asana_client = double("asana_client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)
    end

    it "uploads a file successfully" do
      allow(@asana_client_tasks).to receive(:find_by_id).with("123").and_return(@task)
      allow(@task).to receive(:attach).with(filename: "path/to/file.txt", mime: "application/octet-stream")

      expect { upload_file_to_asana_task("123", "path/to/file.txt") }.not_to raise_error
    end

    it "shows error if failure" do
      allow(@asana_client_tasks).to receive(:find_by_id).with("123").and_return(@task)
      allow(@task).to receive(:attach).and_raise(StandardError.new("API Error"))

      expect(Fastlane::UI).to receive(:user_error!).with("Failed to upload file to Asana task: API Error")
      upload_file_to_asana_task("123", "path/to/file.txt")
    end

    def upload_file_to_asana_task(task_id, file_path)
      Fastlane::Helper::AsanaHelper.upload_file_to_asana_task(task_id, file_path, anything)
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
      Fastlane::Helper::AsanaHelper.sanitize_asana_html_notes(content)
    end
  end

  describe "#update_asana_tasks_for_internal_release" do
    let(:params) do
      {
        github_token: "github_token",
        asana_access_token: "secret-token",
        release_task_id: "1234567890",
        target_section_id: "987654321",
        version: "7.122.0",
        platform: "ios"
      }
    end

    before do
      @client = double("Octokit::Client")
      allow(Octokit::Client).to receive(:new).and_return(@client)
      allow(@client).to receive(:latest_release).and_return(double(tag_name: "7.122.0"))
      allow(Fastlane::Helper::GitHelper).to receive(:repo_name).and_return("iOS")

      @asana_client = double("Asana::Client")
      @asana_tasks = double("Asana::Tasks")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).and_return(@asana_client)
      allow(@asana_client).to receive(:tasks).and_return(@asana_tasks)
      allow(@asana_tasks).to receive(:update_task)
      allow(@asana_tasks).to receive(:get_task).and_return(@asana_task)
      allow(@asana_tasks).to receive(:get_subtasks_for_task).and_return([double(gid: "12312312313")])

      allow(Fastlane::Helper::AsanaHelper).to receive(:asana_task_url).and_return("https://app.asana.com/0/1234567890/1234567890")
      allow(Fastlane::Helper::AsanaHelper).to receive(:fetch_release_notes).and_return("Release notes content")
      allow(Fastlane::Helper::AsanaHelper).to receive(:get_task_ids_from_git_log).and_return(["1234567890"])
      allow(Fastlane::Helper::AsanaHelper).to receive(:release_tag_name).and_return("7.122.0")
      allow(Fastlane::Helper::AsanaHelper).to receive(:find_or_create_asana_release_tag).and_return("tag_id")
      allow(Fastlane::Helper::AsanaHelper).to receive(:move_tasks_to_section)
      allow(Fastlane::Helper::AsanaHelper).to receive(:tag_tasks)
    end

    it "completes the update of Asana tasks for internal release" do
      expect(@client).to receive(:latest_release).with("iOS")

      expect(Fastlane::Helper::AsanaHelper).to receive(:fetch_release_notes).with("1234567890", "secret-token")
      expect(Fastlane::Helper::ReleaseTaskHelper).to receive(:construct_release_task_description).with("Release notes content", ["1234567890"])
      expect(Fastlane::Helper::AsanaHelper).to receive(:move_tasks_to_section).with(["1234567890", "1234567890"], "987654321", "secret-token")
      expect(Fastlane::Helper::AsanaHelper).to receive(:tag_tasks).with("tag_id", ["1234567890", "1234567890"], "secret-token")

      html_notes = "Generated HTML notes"
      allow(Fastlane::Helper::ReleaseTaskHelper).to receive(:construct_release_task_description).and_return(html_notes)
      expect(@asana_tasks).to receive(:update_task).with(task_gid: "1234567890", html_notes: html_notes)

      expect(Fastlane::UI).to receive(:message).with("Checking latest public release in GitHub")
      expect(Fastlane::UI).to receive(:success).with("Latest public release: 7.122.0")
      expect(Fastlane::UI).to receive(:message).with("Extracting task IDs from git log since 7.122.0 release")
      expect(Fastlane::UI).to receive(:success).with("1 task(s) found.")
      expect(Fastlane::UI).to receive(:message).with("Fetching release notes from Asana release task (https://app.asana.com/0/1234567890/1234567890)")
      expect(Fastlane::UI).to receive(:success).with("Release notes: Release notes content")
      expect(Fastlane::UI).to receive(:message).with("Generating release task description using fetched release notes and task IDs")
      expect(Fastlane::UI).to receive(:message).with("Updating release task")
      expect(Fastlane::UI).to receive(:success).with("Release task content updated: https://app.asana.com/0/1234567890/1234567890")
      expect(Fastlane::UI).to receive(:message).with("Moving tasks to Validation section")
      expect(Fastlane::UI).to receive(:success).with("All tasks moved to Validation section")
      expect(Fastlane::UI).to receive(:message).with("Fetching or creating 7.122.0 Asana tag")
      expect(Fastlane::UI).to receive(:success).with("7.122.0 tag URL: https://app.asana.com/0/tag_id/list")
      expect(Fastlane::UI).to receive(:message).with("Tagging tasks with 7.122.0 tag")
      expect(Fastlane::UI).to receive(:success).with("All tasks tagged with 7.122.0 tag")

      Fastlane::Helper::AsanaHelper.update_asana_tasks_for_internal_release(params)
    end
  end

  describe ".create_release_task" do
    let(:platform) { "ios" }
    let(:version) { "7.112.09" }
    let(:assignee_id) { "98765" }
    let(:asana_access_token) { "token" }
    let(:template_task_id) { "template123" }
    let(:task_name) { "iOS App Release #{version}" }
    let(:section_id) { "section789" }
    let(:task_id) { "new_task_id" }
    let(:task_url) { "https://app.asana.com/0/0/#{task_id}/f" }

    before do
      allow(Fastlane::Helper::AsanaHelper).to receive(:release_template_task_id).and_return(template_task_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:release_task_name).and_return(task_name)
      allow(Fastlane::Helper::AsanaHelper).to receive(:release_section_id).and_return(section_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:asana_task_url).with(task_id).and_return(task_url)
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      @asana_client = double("Asana::Client")
      @asana_tasks = double("Asana::Tasks")
      @asana_sections = double("Asana::Sections")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).and_return(@asana_client)
      allow(@asana_client).to receive(:tasks).and_return(@asana_tasks)
      allow(@asana_client).to receive(:sections).and_return(@asana_sections)

      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:success)
    end

    it "creates a release task successfully" do
      allow(HTTParty).to receive(:post).and_return(double(success?: true, parsed_response: { 'data' => { 'new_task' => { 'gid' => task_id } } }))

      expect(HTTParty).to receive(:post).with(
        "#{Fastlane::Helper::AsanaHelper::ASANA_API_URL}/task_templates/#{template_task_id}/instantiateTask",
        headers: { 'Authorization' => "Bearer #{asana_access_token}", 'Content-Type' => 'application/json' },
        body: { data: { name: task_name } }.to_json
      )

      expect(@asana_sections).to receive(:add_task_for_section).with(section_gid: section_id, task: task_id)
      expect(@asana_tasks).to receive(:update_task).with(task_gid: task_id, assignee: assignee_id)

      Fastlane::Helper::AsanaHelper.create_release_task(platform, version, assignee_id, asana_access_token)

      expect(Fastlane::UI).to have_received(:message).with("Creating release task for #{version}")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_task_id", task_id)
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_task_url", task_url)
      expect(Fastlane::UI).to have_received(:success).with("Release task for #{version} created at #{task_url}")
      expect(Fastlane::UI).to have_received(:message).with("Moving release task to section #{section_id}")
      expect(Fastlane::UI).to have_received(:message).with("Assigning release task to user #{assignee_id}")
      expect(Fastlane::UI).to have_received(:success).with("Release task ready: #{task_url} ✅")
    end

    it "raises an error when task creation fails" do
      allow(HTTParty).to receive(:post).and_return(double(success?: false, code: 500, message: "Internal Server Error"))

      expect do
        Fastlane::Helper::AsanaHelper.create_release_task(platform, version, assignee_id, asana_access_token)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, "Failed to instantiate task from template #{template_task_id}: (500 Internal Server Error)")
    end
  end

  describe ".update_asana_tasks_for_public_release" do
    let(:params) do
      {
        github_token: "github_token",
        asana_access_token: "secret-token",
        release_task_id: "1234567890",
        target_section_id: "987654321",
        version: "7.122.0",
        platform: "ios"
      }
    end

    let(:tag_name) { "7.122.0" }
    let(:tag_id) { "7.122.0" }
    let(:task_ids) { ["1234567890", "1234567891", "1234567892"] }
    let(:release_notes) { "Release notes content" }

    before do
      allow(Fastlane::Helper::AsanaHelper).to receive(:release_tag_name).and_return(tag_name)
      allow(Fastlane::Helper::AsanaHelper).to receive(:find_asana_release_tag).and_return(tag_id)
      allow(Fastlane::Helper::AsanaHelper).to receive(:asana_tag_url).with(tag_id).and_return("https://app.asana.com/0/#{tag_id}/list")
      allow(Fastlane::Helper::AsanaHelper).to receive(:fetch_tasks_for_tag).and_return(task_ids)
      allow(Fastlane::Helper::AsanaHelper).to receive(:move_tasks_to_section)
      allow(Fastlane::Helper::AsanaHelper).to receive(:complete_tasks)
      allow(Fastlane::Helper::AsanaHelper).to receive(:fetch_release_notes).and_return(release_notes)
      allow(Fastlane::Helper::ReleaseTaskHelper).to receive(:construct_release_announcement_task_description)

      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:success)
    end

    it "updates Asana tasks for a public release" do
      expect(Fastlane::Helper::AsanaHelper).to receive(:release_tag_name).with(params[:version], params[:platform])
      expect(Fastlane::Helper::AsanaHelper).to receive(:find_asana_release_tag).with(tag_name, params[:release_task_id], params[:asana_access_token])
      expect(Fastlane::Helper::AsanaHelper).to receive(:asana_tag_url).with(tag_id)
      expect(Fastlane::Helper::AsanaHelper).to receive(:fetch_tasks_for_tag).with(tag_id, params[:asana_access_token])
      expect(Fastlane::Helper::AsanaHelper).to receive(:move_tasks_to_section).with(task_ids, params[:target_section_id], params[:asana_access_token])
      expect(Fastlane::Helper::AsanaHelper).to receive(:complete_tasks).with(task_ids, params[:asana_access_token])
      expect(Fastlane::Helper::AsanaHelper).to receive(:fetch_release_notes).with(params[:release_task_id], params[:asana_access_token])
      expect(Fastlane::Helper::ReleaseTaskHelper).to receive(:construct_release_announcement_task_description).with(params[:version], release_notes, task_ids - [params[:release_task_id]], "ios")
      Fastlane::Helper::AsanaHelper.update_asana_tasks_for_public_release(params)

      expect(Fastlane::UI).to have_received(:message).with("Fetching #{tag_name} Asana tag")
      expect(Fastlane::UI).to have_received(:success).with("#{tag_name} tag URL: https://app.asana.com/0/#{tag_id}/list")
      expect(Fastlane::UI).to have_received(:message).with("Fetching tasks tagged with #{tag_name}")
      expect(Fastlane::UI).to have_received(:success).with("3 task(s) found.")
      expect(Fastlane::UI).to have_received(:message).with("Moving tasks to Done section")
      expect(Fastlane::UI).to have_received(:success).with("All tasks moved to Done section")
      expect(Fastlane::UI).to have_received(:message).with("Completing tasks")
      expect(task_ids).to eq(["1234567891", "1234567892"]) # Check function removes release task
      expect(Fastlane::UI).to have_received(:message).with("Done completing tasks")
      expect(Fastlane::UI).to have_received(:message).with("Fetching release notes from Asana release task (https://app.asana.com/0/0/1234567890/f)")
      expect(Fastlane::UI).to have_received(:success).with("Release notes: #{release_notes}")
      expect(Fastlane::UI).to have_received(:message).with("Preparing release announcement task")
    end
  end

  describe ".fetch_tasks_for_tag" do
    let(:tag_id) { "7.122.0" }
    let(:task_ids) { ["12345", "67890", "54321"] }
    let(:asana_access_token) { "secret-token" }

    before do
      @asana_client = double("Asana::Client")
      @asana_tasks = double("Asana::Tasks")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
      allow(@asana_client).to receive(:tasks).and_return(@asana_tasks)
      allow(Fastlane::UI).to receive(:user_error!)
    end

    it "fetches tasks for a given tag successfully with a next page" do
      task1 = double("Asana::Task", gid: "12345")
      task2 = double("Asana::Task", gid: "67890")
      task3 = double("Asana::Task", gid: "54321")

      response_page1 = double(
        "Asana::Collection",
        data: [task1, task2]
      )

      response_page2 = double(
        "Asana::Collection",
        data: [task3]
      )
      allow(response_page1).to receive(:map).and_return(["12345", "67890"])
      allow(response_page1).to receive(:next_page).and_return(response_page2)

      allow(response_page2).to receive(:map).and_return(["54321"])
      allow(response_page2).to receive(:next_page).and_return(nil)

      allow(@asana_tasks).to receive(:get_tasks_for_tag)
        .with(tag_gid: tag_id, options: { fields: ["gid"] })
        .and_return(response_page1)

      allow(@asana_tasks).to receive(:get_tasks_for_tag)
        .with(tag_gid: tag_id, options: { fields: ["gid"], offset: "eyJ0eXAiOJiKV1iQLCJhbGciOiJIUzI1NiJ9" })
        .and_return(response_page2)

      result = Fastlane::Helper::AsanaHelper.fetch_tasks_for_tag(tag_id, asana_access_token)

      expect(result).to eq(["12345", "67890", "54321"])
    end

    it "handles errors and raises a user error" do
      allow(@asana_tasks).to receive(:get_tasks_for_tag).and_raise(StandardError, "API Error")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to fetch tasks for tag: API Error")

      result = Fastlane::Helper::AsanaHelper.fetch_tasks_for_tag(tag_id, asana_access_token)
      expect(result).to eq([])
    end
  end

  describe ".fetch_subtasks" do
    let(:task_id) { "1234567890" }
    let(:asana_access_token) { "secret-token" }

    before do
      @asana_client = double("Asana::Client")
      @asana_tasks = double("Asana::Tasks")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
      allow(@asana_client).to receive(:tasks).and_return(@asana_tasks)
      allow(Fastlane::UI).to receive(:user_error!)
    end

    it "fetches subtasks for a given task successfully" do
      response_page2 = double(
        "Asana::Collection",
        data: [double("Asana::Task", gid: "54321")]
      )
      allow(response_page2).to receive(:map).and_return(["54321"])
      allow(response_page2).to receive(:next_page).and_return(nil)

      response_page1 = double(
        "Asana::Collection",
        data: [double("Asana::Task", gid: "12345"), double("Asana::Task", gid: "67890")]
      )
      allow(response_page1).to receive(:map).and_return(["12345", "67890"])
      allow(response_page1).to receive(:next_page).and_return(response_page2)

      allow(@asana_tasks).to receive(:get_subtasks_for_task)
        .with(task_gid: task_id, options: { fields: ["gid"] })
        .and_return(response_page1)

      allow(@asana_tasks).to receive(:get_subtasks_for_task)
        .with(task_gid: task_id, options: { fields: ["gid"], offset: "eyJ0eXAiOJiKV1iQLCJhbGciOiJIUzI1NiJ9" })
        .and_return(response_page2)

      result = Fastlane::Helper::AsanaHelper.fetch_subtasks(task_id, asana_access_token)

      expect(result).to eq(["12345", "67890", "54321"])
    end

    it "handles errors when fetching subtasks" do
      allow(@asana_tasks).to receive(:get_subtasks_for_task).and_raise(StandardError, "API Error")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to fetch subtasks of task #{task_id}: API Error")

      result = Fastlane::Helper::AsanaHelper.fetch_subtasks(task_id, asana_access_token)
      expect(result).to eq([])
    end
  end

  describe "#get_task_ids_from_git_log" do
    it "extracts Asana task IDs from git log" do
      git_log = <<~LOG
commit 1b6f8be812eac431d4e36ec24d4344369f4ce470

    Bump version to 1.115.0 (312)

commit ca70d42a7c4e2f1b62f6716eb08d286f2a218c4d

    Add attemptCount and maxAttempts to broker config (#3533)
    Task/Issue URL:https://app.asana.com/0/72649045549333/1208700893044577/f
    Tech Design URL:
    https://app.asana.com/0/481882893211075/1208663928051302/f
    CC:

    **Definition of Done**:
#{'    '}
    * [ ] Does this PR satisfy our [Definition of
    Done](https://app.asana.com/0/1202500774821704/1207634633537039/f)?

commit 7202ff2597d21db57fd6dc9a295e11991c81b3e7

    Hide continue setup cards after 1 week (#3471)
#{'    '}
    Task/Issue URL: https://app.asana.com/0/1202406491309510/1208589738926535/f

commit e83fd007c0bdf054658068a79f5b7ea45d846468

    Receive privacy config updates in AddressBarModel on main thread (#3574)
#{'    '}
    Task/Issue URL:#{' '}
#{'    '}
    https://app.asana.com/0/1201037661562251/1208804405760977/f
#{'    '}
    Description:
    This privacy config update may update a published value so must be received on main thread.

commit 9587487662876eee3f2606cf5040d4ee80e0c0a7

    Add expectation when checking email text field value (#3572)
#{'    '}
    Task/Issue URL:
    Tech Design URL:
    CC:
#{'    '}
    **Description**:
    * [x] Does this PR satisfy our [Definition of
    Done](https://app.asana.com/0/1202500774821704/1207634633537039/f)?
#{'    '}
    ###### Internal references:
    [Pull Request Review
    Checklist](https://app.asana.com/0/1202500774821704/1203764234894239/f)
    [Software Engineering
    Expectations](https://app.asana.com/0/59792373528535/199064865822552)
    [Technical Design
    Template](https://app.asana.com/0/59792373528535/184709971311943)
    [Pull Request
    Documentation](https://app.asana.com/0/1202500774821704/1204012835277482/f)
      LOG

      allow(Fastlane::Helper::AsanaHelper).to receive(:`).with("git log v1.0.0..HEAD").and_return(git_log)

      task_ids = Fastlane::Helper::AsanaHelper.get_task_ids_from_git_log("v1.0.0")
      expect(task_ids).to eq(["1208700893044577", "1208589738926535", "1208804405760977"])
    end

    it "returns an empty array if no task IDs are found" do
      allow(Fastlane::Helper::AsanaHelper).to receive(:`).with("git log v1.0.0..HEAD").and_return("No tasks here.")

      task_ids = Fastlane::Helper::AsanaHelper.get_task_ids_from_git_log("v1.0.0")
      expect(task_ids).to eq([])
    end
  end

  describe ".move_tasks_to_section" do
    let(:task_ids) { ["task1", "task2", "task3"] }
    let(:section_id) { "987654321" }
    let(:asana_access_token) { "secret-token" }

    before do
      @asana_client = double("Asana::Client")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
      allow(@asana_client).to receive_message_chain(:batch_apis, :create_batch_request)
      allow(Fastlane::UI).to receive(:message)
    end

    it "moves tasks to the specified section in batches" do
      expect(Fastlane::UI).to receive(:message).with("Moving tasks task1, task2, task3 to section #{section_id}")
      Fastlane::Helper::AsanaHelper.move_tasks_to_section(task_ids, section_id, asana_access_token)
    end
  end

  describe ".complete_tasks" do
    let(:task_ids) { ["1234567890", "1234567891", "1234567892"] }
    let(:asana_access_token) { "secret-token" }
    let(:incident_task_ids) { ["1234567890"] }

    before do
      @asana_client = double("Asana::Client")
      @asana_projects = double("Asana::Projects")
      @asana_tasks = double("Asana::Tasks")

      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
      allow(Fastlane::Helper::AsanaHelper).to receive(:fetch_subtasks).with(Fastlane::Helper::AsanaHelper::INCIDENTS_PARENT_TASK_ID, asana_access_token).and_return(incident_task_ids)

      allow(@asana_client).to receive(:projects).and_return(@asana_projects)
      allow(@asana_client).to receive(:tasks).and_return(@asana_tasks)
      allow(Fastlane::UI).to receive(:user_error!)
    end

    it "completes tasks while skipping incident and current objective tasks" do
      response_task1 = double("Asana::Collection", data: [double("Asana::Project", gid: Fastlane::Helper::AsanaHelper::INCIDENTS_PARENT_TASK_ID)])
      allow(response_task1).to receive(:map).and_return([Fastlane::Helper::AsanaHelper::INCIDENTS_PARENT_TASK_ID])
      allow(@asana_projects).to receive(:get_projects_for_task)
        .with(task_gid: "1234567890", options: { fields: ["gid"] })
        .and_return(response_task1)

      response_task2 = double("Asana::Collection", data: [double("Asana::Project", gid: "non_objective_id")])
      allow(response_task2).to receive(:map).and_return(["non_objective_id"])
      allow(@asana_projects).to receive(:get_projects_for_task)
        .with(task_gid: "1234567891", options: { fields: ["gid"] })
        .and_return(response_task2)

      response_task3 = double("Asana::Collection", data: [double("Asana::Project", gid: Fastlane::Helper::AsanaHelper::CURRENT_OBJECTIVES_PROJECT_ID)])
      allow(response_task3).to receive(:map).and_return([Fastlane::Helper::AsanaHelper::CURRENT_OBJECTIVES_PROJECT_ID])
      allow(@asana_projects).to receive(:get_projects_for_task)
        .with(task_gid: "1234567892", options: { fields: ["gid"] })
        .and_return(response_task3)

      expect(@asana_tasks).to receive(:update_task)
        .with(task_gid: "1234567891", completed: true)
        .and_return(double("update_response"))

      expect(Fastlane::UI).to receive(:important).with("Not completing task 1234567890 because it's an incident task")
      expect(Fastlane::UI).to receive(:message).with("Completing task 1234567891")
      expect(Fastlane::UI).to receive(:success).with("Task 1234567891 completed")
      expect(Fastlane::UI).to receive(:important).with("Not completing task 1234567892 because it's a Current Objective")

      Fastlane::Helper::AsanaHelper.complete_tasks(task_ids, asana_access_token)
    end
  end

  describe ".find_asana_release_tag" do
    let(:tag_name) { "7.122.0" }
    let(:release_task_id) { "1234567890" }
    let(:asana_access_token) { "secret-token" }

    before do
      @asana_client = double("Asana::Client")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
      allow(@asana_client).to receive_message_chain(:tasks, :get_task).and_return(double(tags: [double(name: tag_name, gid: "tag_id")]))
    end

    it "returns the tag ID when found in task tags" do
      result = Fastlane::Helper::AsanaHelper.find_asana_release_tag(tag_name, release_task_id, asana_access_token)
      expect(result).to eq("tag_id")
    end
  end

  describe ".find_or_create_asana_release_tag" do
    let(:tag_name) { "7.122.0" }
    let(:release_task_id) { "1234567890" }
    let(:asana_access_token) { "secret-token" }

    before do
      @asana_client = double("Asana::Client")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
    end

    it "finds the release tag if it exists" do
      allow(Fastlane::Helper::AsanaHelper).to receive(:find_asana_release_tag).and_return("tag_id")
      result = Fastlane::Helper::AsanaHelper.find_or_create_asana_release_tag(tag_name, release_task_id, asana_access_token)
      expect(result).to eq("tag_id")
    end

    it "creates the release tag if it does not exist" do
      allow(Fastlane::Helper::AsanaHelper).to receive(:find_asana_release_tag).and_return(nil)
      tags_client = double("Asana::Tags")
      allow(@asana_client).to receive(:tags).and_return(tags_client)
      allow(tags_client).to receive(:create_tag_for_workspace).and_return(double(gid: "new_tag_id"))

      result = Fastlane::Helper::AsanaHelper.find_or_create_asana_release_tag(tag_name, release_task_id, asana_access_token)
      expect(result).to eq("new_tag_id")
    end
  end

  describe ".tag_tasks" do
    let(:tag_id) { "7.122.0" }
    let(:task_ids) { ["task1", "task2", "task3"] }
    let(:asana_access_token) { "secret-token" }

    before do
      @asana_client = double("Asana::Client")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with(asana_access_token).and_return(@asana_client)
      allow(@asana_client).to receive_message_chain(:batch_apis, :create_batch_request)
      allow(Fastlane::UI).to receive(:message)
    end

    it "tags tasks in batches" do
      expect(Fastlane::UI).to receive(:message).with("Tagging tasks task1, task2, task3")
      Fastlane::Helper::AsanaHelper.tag_tasks(tag_id, task_ids, asana_access_token)
    end
  end
end
