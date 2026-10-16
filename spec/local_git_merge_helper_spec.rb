require 'fileutils'
require 'open3'
require 'tmpdir'
require 'fastlane/plugin/ddg_apple_automation/helper/local_git_merge_helper'

describe Fastlane::Helper::LocalGitMergeHelper do
  let(:helper) { described_class }
  let(:token) { 'secret-token' }
  let(:base_branch) { 'integration' }
  let(:source) { '1.2.3-4+ios' }

  def fixture_git(*arguments)
    stdout, stderr, status = Open3.capture3(@identity, 'git', '-C', @remote, *arguments)
    raise stderr unless status.success?

    stdout.strip
  end

  def commit_file(name, contents)
    File.write(File.join(@remote, name), contents)
    fixture_git('add', name)
    fixture_git('commit', '-m', name)
    fixture_git('rev-parse', 'HEAD')
  end

  before do
    @identity = {
      'GIT_AUTHOR_NAME' => 'Test', 'GIT_AUTHOR_EMAIL' => 'test@example.com',
      'GIT_COMMITTER_NAME' => 'Test', 'GIT_COMMITTER_EMAIL' => 'test@example.com'
    }
    @root = Dir.mktmpdir('ort-spec-', ENV.fetch('KAINBAN_FILES_DIR', nil))
    @remote = File.join(@root, 'remote')
    FileUtils.mkdir_p(@remote)
    fixture_git('init', '--quiet')
    fixture_git('checkout', '-b', base_branch)
    commit_file('shared.txt', "original\n")
    fixture_git('checkout', '-b', 'release/ios/1.2.3')
    @tag_sha = commit_file('release.txt', "tagged\n")
    fixture_git('tag', '-a', source, '-m', 'Release')
    @branch_sha = commit_file('untagged.txt', "untagged\n")
    fixture_git('checkout', base_branch)
    @base_sha = commit_file('base.txt', "base\n")
    @commands = []
    @directories = []
    @published = []

    allow(helper).to receive(:git).and_wrap_original do |original, directory, environment, *arguments|
      @directories << directory
      @commands << arguments
      if arguments.first == 'fetch'
        expect(arguments[3]).to eq('https://github.com/duckduckgo/apple-browsers.git')
        arguments[3] = @remote
      elsif arguments.first == 'push'
        expect(arguments).to eq(['push', 'https://github.com/duckduckgo/apple-browsers.git', "HEAD:refs/heads/#{base_branch}"])
        @before_publish.call if @before_publish
        @published << {
          parents: original.call(directory, environment, 'show', '-s', '--format=%P', 'HEAD').split,
          files: original.call(directory, environment, 'ls-tree', '--name-only', 'HEAD').split
        }
        next ''
      end
      original.call(directory, environment, *arguments)
    end
  end

  after do
    FileUtils.remove_entry(@root)
    expect(@directories.uniq).to all(satisfy { |directory| !File.exist?(directory) })
  end

  def merge(ref = source)
    helper.merge('duckduckgo/apple-browsers', ref, base_branch, token)
  end

  it 'merges an annotated release tag with ort without including later branch commits' do
    merge

    expect(@commands).to include(['merge', '--strategy=ort', '--no-ff', '--no-edit', @tag_sha])
    expect(@published).to eq([{ parents: [@base_sha, @tag_sha], files: ['base.txt', 'release.txt', 'shared.txt'] }])
  end

  it 'merges the branch including untagged commits for public release cleanup' do
    merge('release/ios/1.2.3')

    expect(@published.first[:parents]).to eq([@base_sha, @branch_sha])
    expect(@published.first[:files]).to include('untagged.txt')
  end

  it 'does not publish when the source is already merged' do
    fixture_git('merge', '--no-ff', '--no-edit', source)
    merge

    expect(@published).to be_empty
    expect(@commands.none? { |command| command.first == 'push' }).to be(true)
  end

  it 'cleans up genuine conflicts without publishing or changing the checkout' do
    fixture_git('checkout', 'release/ios/1.2.3')
    commit_file('shared.txt', "release conflict\n")
    fixture_git('checkout', base_branch)
    head = commit_file('shared.txt', "base conflict\n")

    expect { merge('release/ios/1.2.3') }.to raise_error(/git merge failed:.*CONFLICT/m)
    expect(@published).to be_empty
    expect(fixture_git('rev-parse', 'HEAD')).to eq(head)
    expect(fixture_git('status', '--porcelain')).to be_empty
  end

  it 'reports a concurrent base update without retrying or force pushing' do
    @before_publish = proc do
      commit_file('concurrent.txt', "new base\n")
      raise 'non-fast-forward'
    end

    expect { merge }.to raise_error(/remote base may have advanced.*non-fast-forward/)
    expect(@commands.count { |command| command.first == 'push' }).to eq(1)
    expect(@published).to be_empty
    expect(fixture_git('show', 'HEAD:concurrent.txt')).to eq('new base')
  end

  it 'reports protection rejection as a failure' do
    @before_publish = proc { raise 'protected branch update failed' }

    expect { merge }.to raise_error(/branch protections rejected.*protected branch update failed/)
    expect(@published).to be_empty
  end

  it 'works from a detached dirty checkout without changing it' do
    fixture_git('checkout', '--detach', @branch_sha)
    File.write(File.join(@remote, 'release.txt'), "local edits\n")
    head = fixture_git('rev-parse', 'HEAD')
    status = fixture_git('status', '--porcelain')

    Dir.chdir(@remote) { merge }

    expect(@published.length).to eq(1)
    expect(fixture_git('rev-parse', 'HEAD')).to eq(head)
    expect(fixture_git('status', '--porcelain')).to eq(status)
  end

  it 'fails clearly for a missing source without publishing' do
    expect { merge('missing-tag') }.to raise_error(/git fetch failed/)
    expect(@published).to be_empty
  end

  it 'keeps credentials out of command arguments, repository configuration and errors' do
    allow(helper).to receive(:git).and_call_original
    environment = helper.send(:git_environment, token)
    authorization = environment.fetch('GIT_CONFIG_VALUE_1').split.last
    status = double(success?: false)
    allow(Open3).to receive(:capture3)
      .with(environment, 'git', '-C', @remote, 'fetch', 'remote', 'source')
      .and_return(['', "rejected #{token} #{authorization}", status])

    expect { helper.send(:git, @remote, environment, 'fetch', 'remote', 'source') }
      .to raise_error('git fetch failed: rejected [REDACTED] [REDACTED]')
    expect(File.read(File.join(@remote, '.git/config'))).not_to include(token, authorization)
  end
end
