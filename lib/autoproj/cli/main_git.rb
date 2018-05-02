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

            desc 'authors', 'list all authors (useful to tune a mailmap file)'
            def authors
                require 'autoproj/cli/git'
                Autoproj.report(silent: true) do
                    cli = Git.new
                    _, options = cli.validate_options([], self.options)
                    cli.authors(options)
                end
            end

            desc 'ext-stats', 'show diffstat statistics on a per-extension basis'
            def ext_stats
                require 'autoproj/cli/git'
                Autoproj.report(silent: true) do
                    cli = Git.new
                    _, options = cli.validate_options([], self.options)
                    cli.extension_stats(options)
                end
            end

            desc 'author-stats AUTHOR [PACKAGES]', 'show diffstat statistics about a given author'
            option :include, type: :string,
                desc: 'regular expression of file names that should be counted'
            option :exclude, type: :string,
                desc: 'regular expression of file names that should not be counted'
            def author_stats(*authors)
                require 'autoproj/cli/git'
                Autoproj.report(silent: true) do
                    cli = Git.new
                    authors, options = cli.validate_options(authors, self.options)
                    cli.author_stats(authors, options)
                end
            end
        end
    end
end

