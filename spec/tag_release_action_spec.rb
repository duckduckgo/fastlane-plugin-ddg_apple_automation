shared_context "common setup" do
  before do
    @params = {
      asana_access_token: "asana-token",
      asana_task_url: "https://app.asana.com/0/0/1/f",
      is_prerelease: true,
      github_token: "github-token"
    }
    @other_action = double(ensure_git_branch: nil)
    @tag_and_release_output = {}
    allow(Fastlane::Action).to receive(:other_action).and_return(@other_action)
    allow(Fastlane::Helper).to receive(:setup_git_user)
  end
end

shared_context "on ios" do
  before do
    @params[:platform] = "ios"
    Fastlane::Actions::TagReleaseAction.setup_constants(@params[:platform])
  end
end

shared_context "on macos" do
  before do
    @params[:platform] = "macos"
    Fastlane::Actions::TagReleaseAction.setup_constants(@params[:platform])
  end
end

shared_context "for prerelease" do
  before do
    @params[:is_prerelease] = true
    @tag = "1.1.0-123"
    @promoted_tag = nil
    allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, @promoted_tag])
  end
end

shared_context "for public release" do
  before do
    @params[:is_prerelease] = false
    @tag = "1.1.0"
    @promoted_tag = "1.1.0-123"
    allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, @promoted_tag])
  end
end

describe Fastlane::Actions::TagReleaseAction do
  describe "#run" do
    subject do
      configuration = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::TagReleaseAction, @params)
      Fastlane::Actions::TagReleaseAction.run(configuration)
    end

    include_context "common setup"

    before do
      allow(Fastlane::Actions::TagReleaseAction).to receive(:create_tag_and_github_release).and_return(@tag_and_release_output)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:report_status)
    end

    it "creates tag and release, merges branch and reports status" do
      subject

      expect(@tag_and_release_output[:merge_or_delete_successful]).to be_truthy
      # expect(Fastlane::Actions::TagReleaseAction).to have_received(:report_status).with("macos")
    end

    it "reports status when merge or delete failed" do
      allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch).and_raise(StandardError)
      subject

      expect(@tag_and_release_output[:merge_or_delete_successful]).to be_falsy
      # expect(Fastlane::Actions::TagReleaseAction).to have_received(:report_status).with("macos")
    end
  end

  describe "#create_tag_and_github_release" do
    subject { Fastlane::Actions::TagReleaseAction.create_tag_and_github_release(@params[:is_prerelease], @params[:github_token]) }

    let (:latest_public_release) { double(tag_name: "1.0.0") }
    let (:generated_release_notes) { { body: { "name" => "1.1.0", "body" => "Release notes" } } }
    let (:other_action) { double(add_git_tag: nil, push_git_tags: nil, github_api: generated_release_notes, set_github_release: nil) }
    let (:octokit_client) { double(latest_release: latest_public_release) }

    shared_context "local setup" do
      before(:each) do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(JSON).to receive(:parse).and_return(generated_release_notes[:body])
        allow(Fastlane::Action).to receive(:other_action).and_return(other_action)
        allow(Fastlane::UI).to receive(:message)
        allow(Fastlane::UI).to receive(:important)
      end
    end

    shared_examples "expected" do |repo_name|
      let (:repo_name) { repo_name }

      it "creates tag and github release" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: true,
              latest_public_release_tag: latest_public_release.tag_name
            })

        expect(Fastlane::UI).to have_received(:message).with("Latest public release: #{latest_public_release.tag_name}").ordered
        expect(Fastlane::UI).to have_received(:message).with("Generating #{repo_name} release notes for GitHub release for tag: #{@tag}").ordered
        expect(other_action).to have_received(:add_git_tag).with(tag: @tag)
        expect(other_action).to have_received(:push_git_tags).with(tag: @tag)

        expect(other_action).to have_received(:github_api).with(
          api_bearer: @params[:github_token],
          http_method: "POST",
          path: "/repos/#{repo_name}/releases/generate-notes",
          body: {
            tag_name: @tag,
            previous_tag_name: latest_public_release.tag_name
          }
        )

        expect(JSON).to have_received(:parse).with(generated_release_notes[:body])

        expect(other_action).to have_received(:set_github_release).with(
          repository_name: repo_name,
          api_bearer: @params[:github_token],
          tag_name: @tag,
          name: generated_release_notes[:body]["name"],
          description: generated_release_notes[:body]["body"],
          is_prerelease: @params[:is_prerelease]
        )
        expect(Fastlane::UI).not_to have_received(:important)
      end
    end

    shared_context "when failed to create tag" do
      before do
        allow(other_action).to receive(:add_git_tag).and_raise(StandardError)
      end
    end

    shared_context "when failed to push tag" do
      before do
        allow(other_action).to receive(:push_git_tags).and_raise(StandardError)
      end
    end

    shared_context "when failed to fetch latest GitHub release" do
      before do
        allow(octokit_client).to receive(:latest_release).and_raise(StandardError)
      end
    end

    shared_context "when failed to generate GitHub release notes" do
      before do
        allow(other_action).to receive(:github_api).and_raise(StandardError)
      end
    end

    shared_context "when failed to parse GitHub response" do
      before do
        allow(JSON).to receive(:parse).and_raise(StandardError)
      end
    end

    shared_context "when failed to create GitHub release" do
      before do
        allow(other_action).to receive(:set_github_release).and_raise(StandardError)
      end
    end

    shared_examples "gracefully handling tagging error" do
      it "handles tagging error" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: false
            })
        expect(Fastlane::UI).to have_received(:important).with("Failed to create and push tag: StandardError")
      end
    end

    shared_examples "gracefully handling GitHub release error" do |reports_latest_public_release_tag|
      let (:reports_latest_public_release_tag) { reports_latest_public_release_tag }

      it "handles GitHub release error" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: true,
              latest_public_release_tag: reports_latest_public_release_tag ? latest_public_release.tag_name : nil
            })
        expect(Fastlane::UI).to have_received(:important).with("Failed to create GitHub release: StandardError")
      end
    end

    include_context "common setup"
    include_context "local setup"

    tag_contexts = ["create tag", "push tag"]
    github_release_contexts = [
      { action: "fetch latest GitHub release", includes_latest_public_release_tag: false },
      { action: "generate GitHub release notes", includes_latest_public_release_tag: true },
      { action: "parse GitHub response", includes_latest_public_release_tag: true },
      { action: "create GitHub release", includes_latest_public_release_tag: true }
    ]

    context "on ios" do
      include_context "on ios"

      context "for prerelease" do
        include_context "for prerelease"
        it_behaves_like "expected", "duckduckgo/ios"

        tag_contexts.each do |action|
          context "when failed to #{action}" do
            include_context "when failed to #{action}"
            it_behaves_like "gracefully handling tagging error"
          end
        end

        github_release_contexts.each do |context_data|
          context "when failed to #{context_data[:action]}" do
            include_context "when failed to #{context_data[:action]}"
            it_behaves_like "gracefully handling GitHub release error", context_data[:includes_latest_public_release_tag]
          end
        end

        context "for public release" do
          include_context "for public release"
          it_behaves_like "expected", "duckduckgo/ios"

          tag_contexts.each do |action|
            context "when failed to #{action}" do
              include_context "when failed to #{action}"
              it_behaves_like "gracefully handling tagging error"
            end
          end

          github_release_contexts.each do |context_data|
            context "when failed to #{context_data[:action]}" do
              include_context "when failed to #{context_data[:action]}"
              it_behaves_like "gracefully handling GitHub release error", context_data[:includes_latest_public_release_tag]
            end
          end
        end
      end

      context "on macos" do
        include_context "on macos"

        context "for prerelease" do
          include_context "for prerelease"
          it_behaves_like "expected", "duckduckgo/macos-browser"

          tag_contexts.each do |action|
            context "when failed to #{action}" do
              include_context "when failed to #{action}"
              it_behaves_like "gracefully handling tagging error"
            end
          end

          github_release_contexts.each do |context_data|
            context "when failed to #{context_data[:action]}" do
              include_context "when failed to #{context_data[:action]}"
              it_behaves_like "gracefully handling GitHub release error", context_data[:includes_latest_public_release_tag]
            end
          end
        end

        context "for public release" do
          include_context "for public release"
          it_behaves_like "expected", "duckduckgo/macos-browser"

          tag_contexts.each do |action|
            context "when failed to #{action}" do
              include_context "when failed to #{action}"
              it_behaves_like "gracefully handling tagging error"
            end
          end

          github_release_contexts.each do |context_data|
            context "when failed to #{context_data[:action]}" do
              include_context "when failed to #{context_data[:action]}"
              it_behaves_like "gracefully handling GitHub release error", context_data[:includes_latest_public_release_tag]
            end
          end
        end
      end
    end
  end
end
