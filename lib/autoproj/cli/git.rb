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
                                   ignore_non_imported_packages: true)
                git_packages = source_packages.map do |pkg_name|
                    pkg = ws.manifest.find_autobuild_package(pkg_name)
                    pkg if pkg.importer.kind_of?(Autobuild::Git)
                end.compact

                git_packages.each_with_index do |pkg, i|
                    cleanup_package(pkg, "[#{i}/#{git_packages.size}] ",
                                    local: options[:local],
                                    remove_obsolete_remotes: options[:remove_obsolete_remotes])
                end
            end

            def git_gc(pkg, progress)
                pkg.progress_start "#{progress}%s: gc", done_message: "#{progress}%s: gc" do
                    pkg.importer.run_git_bare(pkg, 'gc')
                end
            end

            def git_repack(pkg, progress)
                pkg.progress_start "#{progress}%s: repack", done_message: "#{progress}%s: gc" do
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
                remotes = git_all_remotes(pkg)
                remotes.each do |remote_name|
                    pkg.progress_start "#{progress}%s: pruning #{remote_name}", done_message: "#{progress}%s: pruned #{remote_name}" do
                        pkg.importer.run_git(pkg, 'remote', 'prune', remote_name)
                    end
                end
            end

            def git_remove_obsolete_remotes(pkg, progress)
                remotes = git_all_remotes(pkg)
                pkg.importer.each_configured_remote do |remote_name, _|
                    remotes.delete(remote_name)
                end

                remotes.each do |remote_name|
                    pkg.progress_start "#{progress}%s: removing remote #{remote_name}", done_message: "#{progress}%s: removed remote #{remote_name}" do
                        pkg.importer.run_git(pkg, 'remote', 'rm', remote_name)
                    end
                end
            end

            def cleanup_package(pkg, progress, options = Hash.new)
                git_gc(pkg, progress)
                git_repack(pkg, progress)

                if options[:remove_obsolete_remotes]
                    git_remove_obsolete_remotes(pkg, progress)
                end
                if !options[:local]
                    git_remote_prune(pkg, progress)
                end
            end
        end
    end
end
