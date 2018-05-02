require 'autoproj'
require 'autoproj/cli/inspection_tool'
require 'tty-table'

module Autoproj
    module CLI
        class Git < InspectionTool
            def cleanup(user_selection, options = Hash.new)
                git_packages = resolve_selected_git_packages(user_selection)
                run_parallel(git_packages) do |pkg, i|
                    cleanup_package(pkg, " [#{i}/#{git_packages.size}]",
                                    local: options[:local],
                                    remove_obsolete_remotes: options[:remove_obsolete_remotes])
                end
            end

            MATCH_ALL  = proc { true }
            MATCH_NONE = proc { }

            def authors(options = Hash.new)
                packages = resolve_selected_git_packages([])
                all_lines = run_parallel(packages) do |pkg, _|
                    pkg.importer.run_git(pkg, 'shortlog', '-s', '-e')
                end.flatten

                all_authors = Set.new
                all_lines.each do |line|
                    match = /^\s*\d+\s+(.+)$/.match(line)
                    all_authors << match[1] if match
                end
                puts all_authors.to_a.sort.join("\n")
            end

            def extension_stats(options = Hash.new)
                git_packages = resolve_selected_git_packages([])

                stats = compute_stats(git_packages) do |pkg, filename|
                    File.extname(filename)
                end
                display_stats(stats)
            end

            def author_stats(authors, options = Hash.new)
                git_packages = resolve_selected_git_packages([])

                include_filter =
                    if options[:include]
                        Regexp.new(options[:include], Regexp::IGNORECASE)
                    else
                        MATCH_ALL
                    end

                exclude_filter =
                    if options[:exclude]
                        Regexp.new(options[:exclude], Regexp::IGNORECASE)
                    else
                        MATCH_NONE
                    end


                stats = compute_stats(git_packages, "--use-mailmap", *authors.map { |a| "--author=#{a}" }) do |pkg, filename|
                    if (include_filter === filename) && !(exclude_filter === filename)
                        pkg.name
                    end
                end
                display_stats(stats)
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

            def resolve_selected_git_packages(user_selection)
                initialize_and_load
                source_packages, * =
                    finalize_setup(user_selection,
                                   non_imported_packages: :ignore)
                source_packages.map do |pkg_name|
                    pkg = ws.manifest.find_autobuild_package(pkg_name)
                    pkg if pkg.importer.kind_of?(Autobuild::Git)
                end.compact
            end

            def run_parallel(objects, &block)
                pool = Concurrent::FixedThreadPool.new(4)
                futures = objects.each_with_index.map do |obj, i|
                    Concurrent::Future.execute(executor: pool) do
                        begin
                            result = yield(obj, i)
                            [result, nil]
                        rescue Autobuild::SubcommandFailed => e
                            Autoproj.error "failed: #{e.message}"
                            [nil, e]
                        end
                    end
                end
                result   = futures.each(&:execute).map(&:value!).compact
                failures = result.map(&:last).compact
                result.map(&:first)
            rescue Interrupt => interrupt
            ensure
                pool.shutdown if pool
                Autobuild::Reporting.report_finish_on_error(
                    failures || [], on_package_failures: :raise, interrupted_by: interrupt)
            end

            def compute_stats(packages, *log_options)
                all_runs = run_parallel(packages) do |pkg, _|
                    lines = pkg.importer.run_git(
                        pkg, 'log', *log_options, '--pretty=tformat:', '--numstat')
                    [pkg, lines]
                end

                all_runs.each_with_object(Hash.new) do |(pkg, lines), stats|
                    lines.each do |l|
                        match = /^\s*(\d+)\s+(\d+)\s+(.*)/.match(l)
                        if match && (key = yield(pkg, match[3]))
                            key_stats = (stats[key] ||= [0, 0])
                            key_stats[0] += Integer(match[1])
                            key_stats[1] += Integer(match[2])
                        end
                    end
                end
            end

            def display_stats(stats, io: STDOUT)
                total_p, total_m = 0, 0
                stats.keys.sort.each do |text|
                    p, m = stats[text]
                    total_p += p
                    total_m += m
                    unless p == 0 && m == 0
                        io.puts format("+%6i -%6i %s", p, m, text)
                    end
                end
                io.puts format("+%6i -%6i %s", total_p, total_m, "Total")
            end
        end
    end
end
