require 'autoproj/cli/main_git'

class Autoproj::CLI::Main
    desc 'git', 'git-specific functionality'
    subcommand 'git', Autoproj::CLI::MainGit
end

