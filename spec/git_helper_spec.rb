describe Fastlane::Helper::GitHelper do
  let(:repo_name) { "repo_name" }
  let(:branch) { "branch" }
  let(:base_branch) { "base_branch" }
  let(:github_token) { "github_token" }
  let(:client) { double("client") }

  shared_context "common setup" do
    before do
      allow(Octokit::Client).to receive(:new).and_return(client)
      allow(Fastlane::UI).to receive(:success)
      allow(Fastlane::UI).to receive(:important)
    end
  end

  describe "#merge_branch" do
    subject { Fastlane::Helper::GitHelper.merge_branch(repo_name, branch, base_branch, github_token) }

    include_context "common setup"

    context "when merge is successful" do
      before do
        allow(client).to receive(:merge)
      end

      it "reports success" do
        expect { subject }.not_to raise_error

        expect(client).to have_received(:merge).with(repo_name, base_branch, branch)
        expect(Fastlane::UI).to have_received(:success).with("Merged #{branch} branch to #{base_branch}")
      end
    end

    context "when merge fails" do
      before do
        allow(client).to receive(:merge).and_raise(StandardError)
      end

      it "shows error" do
        expect { subject }.to raise_error(StandardError)

        expect(client).to have_received(:merge).with(repo_name, base_branch, branch)
        expect(Fastlane::UI).to have_received(:important).with("Failed to merge #{branch} branch to #{base_branch}: StandardError")
      end
    end
  end

  describe "#delete_branch" do
    subject { Fastlane::Helper::GitHelper.delete_branch(repo_name, branch, github_token) }

    include_context "common setup"

    context "when delete is successful" do
      before do
        allow(client).to receive(:delete_branch)
      end

      it "reports success" do
        expect { subject }.not_to raise_error

        expect(client).to have_received(:delete_branch).with(repo_name, branch)
        expect(Fastlane::UI).to have_received(:success).with("Deleted #{branch}")
      end
    end

    context "when delete fails" do
      before do
        allow(client).to receive(:delete_branch).and_raise(StandardError)
      end

      it "shows error" do
        expect { subject }.to raise_error(StandardError)

        expect(client).to have_received(:delete_branch).with(repo_name, branch)
        expect(Fastlane::UI).to have_received(:important).with("Failed to delete #{branch} branch: StandardError")
      end
    end
  end

  describe "#repo_name" do
    subject { Fastlane::Helper::GitHelper.repo_name(platform) }

    let(:platform) { "ios" }

    context "when TEST_MODE is enabled" do
      before do
        allow(ENV).to receive(:[]).with("TEST_MODE").and_return("true")
      end

      it "returns the test repository name" do
        expect(subject).to eq("duckduckgo/apple-automation-test")
      end
    end

    context "when TEST_MODE is disabled and platform is ios" do
      before do
        allow(ENV).to receive(:[]).with("TEST_MODE").and_return(nil)
      end

      it "returns the ios repository name" do
        expect(subject).to eq("duckduckgo/ios")
      end
    end

    context "when TEST_MODE is disabled and platform is macos" do
      let(:platform) { "macos" }

      before do
        allow(ENV).to receive(:[]).with("TEST_MODE").and_return(nil)
      end

      it "returns the macos repository name" do
        expect(subject).to eq("duckduckgo/macos-browser")
      end
    end
  end
end
