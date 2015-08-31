module Autoproj
    module CLI
        # CLI interface for autoproj-git
        class MainGit < Thor
            desc 'cleanup [PACKAGES]', 'perform regular git cleanup operations on all packages'
            option :local, type: :boolean,
                default: false, desc: 'only perform operations that do not require network access'
            option :remove_obsolete_remotes, type: :boolean,
                default: false, desc: 'remove remotes that are not managed by autoproj'
            def cleanup(*packages)
                require 'autoproj/cli/git'
                Autoproj.report(silent: true) do
                    cli = Git.new
                    args = cli.validate_options(packages, options)
                    cli.cleanup(*args)
                end
            end
        end
    end
end

