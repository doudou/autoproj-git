require 'autoproj'
require 'autoproj/cli/inspection_tool'
require 'tty-table'

module Autoproj
    module CLI
        class Git < InspectionTool
            def cleanup(user_selection, options = Hash.new)
                initialize_and_load
                source_packages, * =
                    finalize_setup(user_selection,
                                   non_imported_packages: :ignore)
                git_packages = source_packages.map do |pkg_name|
                    pkg = ws.manifest.find_autobuild_package(pkg_name)
                    pkg if pkg.importer.kind_of?(Autobuild::Git)
                end.compact

                package_failures = []
                pool = Concurrent::FixedThreadPool.new(4)
                futures = git_packages.each_with_index.map do |pkg, i|
                    Concurrent::Future.execute(executor: pool) do
                        begin
                            cleanup_package(pkg, " [#{i}/#{git_packages.size}]",
                                            local: options[:local],
                                            remove_obsolete_remotes: options[:remove_obsolete_remotes])
                            nil
                        rescue Autobuild::SubcommandFailed => e
                            Autoproj.error "failed: #{e.message}"
                            e
                        end
                    end
                end
                package_failures = futures.each(&:execute).map(&:value!).compact
            rescue Interrupt => interrupt
            ensure
                pool.shutdown if pool
                Autobuild::Reporting.report_finish_on_error(
                    package_failures, on_package_failures: :raise, interrupted_by: interrupt)
            end

            def git_clean_invalid_refs(pkg, progress)
                output = pkg.importer.run_git_bare(pkg, 'show-ref')
                output.each do |line|
                    if m = line.match(/error: (.*) does not point to a valid object!/)
                        pkg.importer.run_git_bare(pkg, 'update-ref', '-d', m[1])
                    end
                end
            end

            def git_gc(pkg, progress)
                pkg.progress_start "gc %s#{progress}", done_message: "gc %s#{progress}" do
                    pkg.importer.run_git_bare(pkg, 'gc')
                end
            end

            def git_repack(pkg, progress)
                pkg.progress_start "repack %s#{progress}", done_message: "repack %s#{progress}" do
                    pkg.importer.run_git_bare(pkg, 'repack', '-adl')
                end
            end

            def git_all_remotes(pkg)
                pkg.importer.run_git(pkg, 'config', '--list').
                    map do |line|
                        if match = /remote\.(.*)\.url=/.match(line)
                            match[1]
                        end
                    end.compact.to_set
            end
 
            def git_remote_prune(pkg, progress)
                pkg.progress_start "pruning %s#{progress}", done_message: "pruned %s#{progress}" do
                    pkg.importer.run_git(pkg, 'fetch', '-p')
                end
            end

            def git_remove_obsolete_remotes(pkg, progress)
                remotes = git_all_remotes(pkg)
                pkg.importer.each_configured_remote do |remote_name, _|
                    remotes.delete(remote_name)
                end

                remotes.each do |remote_name|
                    pkg.progress_start "removing remote %s/#{remote_name}#{progress}", done_message: "removed remote %s/#{remote_name}#{progress}" do
                        pkg.importer.run_git(pkg, 'remote', 'rm', remote_name)
                    end
                end
            end

            def cleanup_package(pkg, progress, options = Hash.new)
                git_clean_invalid_refs(pkg, progress)
                if options[:remove_obsolete_remotes]
                    git_remove_obsolete_remotes(pkg, progress)
                end
                if !options[:local]
                    git_remote_prune(pkg, progress)
                end

                git_gc(pkg, progress)
                git_repack(pkg, progress)
            end
        end
    end
end
