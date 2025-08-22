describe Fastlane::Actions::AsanaFindReleaseTaskAction do
  describe "#run" do
    subject { Fastlane::Actions::AsanaFindReleaseTaskAction.run(platform: "ios", asana_access_token: "token") }

    before do
      expect(Fastlane::Helper::GitHelper).to receive(:find_latest_marketing_version).and_return("1.0.0")
      allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:report_hotfix_task)
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      allow(Fastlane::UI).to receive(:success)
    end

    context "when it finds a release task" do
      before do
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task).and_return(["1234567890", nil])
      end

      it "returns release task ID, URL and release branch" do
        expect(subject).to eq({
          release_task_id: "1234567890",
          release_task_url: "https://app.asana.com/0/0/1234567890/f",
          release_branch: "release/ios/1.0.0"
        })

        expect(Fastlane::UI).to have_received(:success).with("Found 1.0.0 release task: https://app.asana.com/0/0/1234567890/f")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_branch", "release/ios/1.0.0")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_task_id", "1234567890")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_task_url", "https://app.asana.com/0/0/1234567890/f")
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to have_received(:report_hotfix_task)
      end
    end

    context "when it finds a release and a hotfix task" do
      before do
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task).and_return(["1234567890", "5555"])
      end

      it "reports the hotfix task and returns early" do
        subject
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to have_received(:report_hotfix_task).with("5555", "1234567890", "token")
      end
    end
  end

  describe "#find_release_task" do
    before do
      Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")

      @tasks = double
      asana_client = double("Asana::Client", tasks: @tasks)
      allow(Asana::Client).to receive(:new).and_return(asana_client)
    end

    describe "when release task is found" do
      describe "on the first page" do
        before do
          expect(@tasks).to receive(:find_all).and_return(double(next_page: nil))
        end

        it "returns the release task ID" do
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task_in_response).and_return("1234567890")

          expect(find_release_task("1.0.0")).to eq(["1234567890", nil])
        end
      end

      describe "on the next page" do
        before do
          non_nil_next_page = double(next_page: nil)
          expect(@tasks).to receive(:find_all).and_return(double(next_page: non_nil_next_page))
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction)
            .to receive(:find_release_task_in_response).twice.and_return(nil, "1234567890")
        end

        it "returns the release task ID" do
          allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
          expect(find_release_task("1.0.0")).to eq(["1234567890", nil])
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to have_received(:find_hotfix_task_in_response).twice
        end
      end
    end

    describe "when fetching tasks in section fails" do
      before do
        expect(@tasks).to receive(:find_all).and_raise(StandardError, "API error")
      end

      it "shows error" do
        allow(Fastlane::UI).to receive(:user_error!)
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to receive(:find_hotfix_task_in_response)
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to receive(:find_release_task_in_response)

        find_release_task("1.0.0")

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch release task: API error")
      end
    end

    describe "when fetching next page fails" do
      before do
        next_page = double
        expect(@tasks).to receive(:find_all).and_return(double(next_page: next_page))
        expect(next_page).to receive(:next_page).and_raise(StandardError, "API error")
      end

      it "shows error" do
        allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
        allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task_in_response).and_return(nil)
        allow(Fastlane::UI).to receive(:user_error!)

        find_release_task("1.0.0")

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch release task: API error")
      end
    end

    def find_release_task(version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_release_task(version, "token")
    end
  end

  describe "#find_release_task_in_response" do
    describe "when release task is found" do
      before do
        Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
        @tasks = [double(
          name: 'iOS App Release 1.0.0',
          gid: '1234567890',
          created_at: '2024-01-01'
        )]
      end

      describe "and the task is not too old" do
        before do
          allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:ensure_task_not_too_old)
        end

        it "returns the release task ID" do
          expect(find_release_task_in_response(@tasks, "1.0.0")).to eq("1234567890")
        end
      end

      describe "and release task is too old" do
        before do
          expect(Time).to receive(:now).and_return(Time.new(2024, 1, 10)).at_least(:once)
        end

        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          find_release_task_in_response(@tasks, "1.0.0")

          expect(Fastlane::UI).to have_received(:user_error!).with("Found release task: 1234567890 but it's older than 5 days, skipping.")
        end
      end
    end

    describe "when release task is not found" do
      describe "on iOS" do
        before do
          Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
        end

        it "returns nil" do
          expect(find_release_task_in_response([double(name: 'iOS App Release 1.0.0')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'iOS Release 1.0.1')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'macOS App Release 1.0.1')], "1.0.1")).to be_nil
        end
      end

      describe "on macOS" do
        before do
          Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("macos")
        end

        it "returns nil" do
          expect(find_release_task_in_response([double(name: 'macOS App Release 1.0.0')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'macOS Release 1.0.1')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'iOS App Release 1.0.1')], "1.0.1")).to be_nil
        end
      end
    end

    def find_release_task_in_response(response, version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_release_task_in_response(response, version)
    end
  end

  describe "#find_hotfix_task_in_response" do
    subject { Fastlane::Actions::AsanaFindReleaseTaskAction.find_hotfix_task_in_response(@tasks) }

    describe "on iOS" do
      before do
        Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
      end

      describe "when hotfix task is present" do
        before do
          @tasks = [double(name: 'iOS App Hotfix Release 1.0.0', gid: '1234567890')]
        end
        it "returns the hotfix task ID" do
          expect(subject).to eq("1234567890")
        end
      end

      describe "when hotfix task is not present" do
        before do
          @tasks = [double(name: 'iOS App Release 1.0.0', gid: '1234567890')]
        end

        it "returns nil" do
          expect(subject).to be_nil
        end
      end
    end

    describe "on macOS" do
      before do
        Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("macos")
      end

      describe "when hotfix task is present" do
        before do
          @tasks = [double(name: 'macOS App Hotfix Release 1.0.0', gid: '1234567890')]
        end

        it "returns the hotfix task ID" do
          expect(subject).to eq("1234567890")
        end
      end

      describe "when hotfix task is not present" do
        before do
          @tasks = [double(name: 'macOS App Release 1.0.0', gid: '1234567890')]
        end

        it "returns nil" do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe "#report_hotfix_task" do
    subject { Fastlane::Actions::AsanaFindReleaseTaskAction.report_hotfix_task(hotfix_task_id, release_task_id, "token") }
    let(:hotfix_task_id) { "12" }
    let(:release_task_id) { "56" }
    let(:asana_client_tasks) { double(add_followers_for_task: nil) }
    let(:asana_client) { double(tasks: asana_client_tasks) }

    before do
      allow(Fastlane::Helper::AsanaHelper).to receive(:asana_task_url).and_return("https://app.asana.com/0/0/#{hotfix_task_id}/f")
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee).with(hotfix_task_id, "token").and_return("34")
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee).with(release_task_id, "token").and_return("78")
      allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).with("token").and_return(asana_client)
      allow(Fastlane::Actions::AsanaAddCommentAction).to receive(:run)
      allow(Fastlane::UI).to receive(:important)
      allow(Fastlane::UI).to receive(:user_error!)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:log_error)
    end

    context "when hotfix task is not found" do
      let(:hotfix_task_id) { nil }

      it "returns early" do
        subject
        expect(Fastlane::Helper::AsanaHelper).not_to have_received(:make_asana_client)
        expect(Fastlane::Helper::AsanaHelper).not_to have_received(:extract_asana_task_assignee)
        expect(Fastlane::Actions::AsanaAddCommentAction).not_to have_received(:run)
      end
    end

    it "adds the release task assignee as a follower to the hotfix task" do
      subject
      expect(Fastlane::Helper::AsanaHelper).to have_received(:make_asana_client).with("token")
      expect(Fastlane::Helper::AsanaHelper).to have_received(:extract_asana_task_assignee).with(hotfix_task_id, "token")
      expect(Fastlane::Helper::AsanaHelper).to have_received(:extract_asana_task_assignee).with(release_task_id, "token")
      expect(Fastlane::UI).to have_received(:important).with("Adding user 78 as collaborator on hotfix release task 12")
      expect(Fastlane::Actions::AsanaAddCommentAction).to have_received(:run).with(
        task_id: hotfix_task_id,
        template_name: 'hotfix-preventing-release-bump',
        template_args: {
          hotfix_task_assignee_id: "34",
          release_task_assignee_id: "78",
          release_task_id: "56"
        },
        asana_access_token: "token"
      )
      expect(Fastlane::UI).to have_received(:user_error!).with("Found active hotfix task: https://app.asana.com/0/0/12/f")
    end

    shared_examples "showing error" do
      it "shows error" do
        subject
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:log_error).with(StandardError)
        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to add release task assignee as collaborator on task 12")
        expect(Fastlane::Actions::AsanaAddCommentAction).not_to have_received(:run)
      end
    end

    context "when extract_asana_task_assignee fails" do
      before do
        allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_assignee).and_raise(StandardError)
      end

      it_behaves_like "showing error"
    end

    context "when make_asana_client fails" do
      before do
        allow(Fastlane::Helper::AsanaHelper).to receive(:make_asana_client).and_raise(StandardError)
      end

      it_behaves_like "showing error"
    end

    context "when add_followers_for_task fails" do
      before do
        allow(asana_client_tasks).to receive(:add_followers_for_task).and_raise(StandardError)
      end

      it_behaves_like "showing error"
    end
  end
end
