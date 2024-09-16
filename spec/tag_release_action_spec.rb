describe Fastlane::Actions::TagReleaseAction do
  before do
    @params = {
      asana_access_token: "asana-token",
      platform: "macos",
      asana_task_url: "https://app.asana.com/0/0/1/f",
      is_prerelease: true,
      github_token: "github-token"
    }
    @other_action = double(ensure_git_branch: nil)
    @tag_and_release_output = {}
    allow(Fastlane::Action).to receive(:other_action).and_return(@other_action)
    allow(Fastlane::Helper).to receive(:setup_git_user)
  end

  describe "#run" do
    before do
      allow(Fastlane::Actions::TagReleaseAction).to receive(:create_tag_and_github_release).and_return(@tag_and_release_output)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:report_status)
    end

    it "creates tag and release, merges branch and reports status" do
      test_action(@params)

      expect(@tag_and_release_output[:merge_or_delete_successful]).to be_truthy
      # expect(Fastlane::Actions::TagReleaseAction).to have_received(:report_status).with("macos")
    end

    it "reports status when merge or delete failed" do
      allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch).and_raise(StandardError)
      test_action(@params)

      expect(@tag_and_release_output[:merge_or_delete_successful]).to be_falsy
      # expect(Fastlane::Actions::TagReleaseAction).to have_received(:report_status).with("macos")
    end

    def test_action(params)
      configuration = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::TagReleaseAction, params)
      Fastlane::Actions::TagReleaseAction.run(configuration)
    end
  end

  describe "#create_tag_and_github_release" do
    let (:latest_public_release) { double(tag_name: "1.0.0") }
    let (:generated_release_notes) { { body: { "name" => "1.1.0", "body" => "Release notes" } } }

    before do
      Fastlane::Actions::TagReleaseAction.setup_constants("macos")
      allow(Octokit::Client).to receive(:new).and_return(double(latest_release: latest_public_release))
      allow(JSON).to receive(:parse).and_return(generated_release_notes[:body])
      @other_action = double(add_git_tag: nil, push_git_tags: nil, github_api: generated_release_notes, set_github_release: nil)
      allow(Fastlane::Action).to receive(:other_action).and_return(@other_action)
      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:important)
    end

    describe "for prerelease" do
      before do
        @params[:is_prerelease] = true
        @tag = "1.1.0-123"
        allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, nil])
      end

      it "creates tag and github release" do
        expect(create_tag_and_github_release(@params)).to eq({
          tag: @tag,
          promoted_tag: nil,
          tag_created: true,
          latest_public_release_tag: latest_public_release.tag_name
        })

        expect(Fastlane::UI).to have_received(:message).with("Latest public release: #{latest_public_release.tag_name}").ordered
        expect(Fastlane::UI).to have_received(:message).with("Generating duckduckgo/macos-browser release notes for GitHub release for tag: #{@tag}").ordered

        expect(@other_action).to have_received(:add_git_tag).with(tag: @tag)
        expect(@other_action).to have_received(:push_git_tags).with(tag: @tag)

        expect(@other_action).to have_received(:github_api).with(
          api_bearer: @params[:github_token],
          http_method: "POST",
          path: "/repos/duckduckgo/macos-browser/releases/generate-notes",
          body: {
            tag_name: @tag,
            previous_tag_name: latest_public_release.tag_name
          }
        )

        expect(JSON).to have_received(:parse).with(generated_release_notes[:body])

        expect(@other_action).to have_received(:set_github_release).with(
          repository_name: "duckduckgo/macos-browser",
          api_bearer: @params[:github_token],
          tag_name: @tag,
          name: generated_release_notes[:body]["name"],
          description: generated_release_notes[:body]["body"],
          is_prerelease: @params[:is_prerelease]
        )
        expect(Fastlane::UI).not_to have_received(:important)
      end
    end

    describe "for public release" do
      before do
        @params[:is_prerelease] = false
        @tag = "1.1.0"
        @promoted_tag = "1.1.0-123"
        allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, @promoted_tag])
      end

      it "creates tag and github release" do
        expect(create_tag_and_github_release(@params)).to eq({
          tag: @tag,
          promoted_tag: @promoted_tag,
          tag_created: true,
          latest_public_release_tag: latest_public_release.tag_name
        })

        expect(Fastlane::UI).to have_received(:message).with("Latest public release: #{latest_public_release.tag_name}").ordered
        expect(Fastlane::UI).to have_received(:message).with("Generating duckduckgo/macos-browser release notes for GitHub release for tag: #{@tag}").ordered
        expect(@other_action).to have_received(:add_git_tag).with(tag: @tag)
        expect(@other_action).to have_received(:push_git_tags).with(tag: @tag)

        expect(@other_action).to have_received(:github_api).with(
          api_bearer: @params[:github_token],
          http_method: "POST",
          path: "/repos/duckduckgo/macos-browser/releases/generate-notes",
          body: {
            tag_name: @tag,
            previous_tag_name: latest_public_release.tag_name
          }
        )

        expect(JSON).to have_received(:parse).with(generated_release_notes[:body])

        expect(@other_action).to have_received(:set_github_release).with(
          repository_name: "duckduckgo/macos-browser",
          api_bearer: @params[:github_token],
          tag_name: @tag,
          name: generated_release_notes[:body]["name"],
          description: generated_release_notes[:body]["body"],
          is_prerelease: @params[:is_prerelease]
        )
        expect(Fastlane::UI).not_to have_received(:important)
      end
    end

    def create_tag_and_github_release(params)
      Fastlane::Actions::TagReleaseAction.create_tag_and_github_release(params[:is_prerelease], params[:github_token])
    end
  end
end
