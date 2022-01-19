require 'cocoapods-binary'

def patch_copy_bundle

  Pod::Installer.define_method :prebuild_frameworks! do |*args|
    puts "copy bundle fixed" .green << "\n"
    Pod::Prebuild.check_one_pod_should_have_only_one_target(self.pod_targets)

    # build options
    sandbox_path = sandbox.root
    existed_framework_folder = sandbox.generate_framework_path
    bitcode_enabled = Pod::Podfile::DSL.bitcode_enabled
    targets = []

    if local_manifest != nil

      changes = prebuild_pods_changes
      added = changes.added
      changed = changes.changed
      unchanged = changes.unchanged
      deleted = changes.deleted

      existed_framework_folder.mkdir unless existed_framework_folder.exist?
      exsited_framework_names = sandbox.exsited_framework_names

      # additions
      missing = unchanged.select do |pod_name|
        not exsited_framework_names.include?(pod_name)
      end


      root_names_to_update = (added + changed + missing)

      # transform names to targets
      name_to_target_hash = self.pod_targets.reduce({}) do |sum, target|
        sum[target.name] = target
        sum
      end
      targets = root_names_to_update.map do |root_name|
        t = name_to_target_hash[root_name]
        raise "There's no target named (#{root_name}) in Pod.xcodeproj.\n #{name_to_target_hash.keys}" if t.nil?
        t
      end || []

      # add the dendencies
      dependency_targets = targets.map {|t| t.recursive_dependent_targets }.flatten.uniq || []
      targets = (targets + dependency_targets).uniq
    else
      targets = self.pod_targets
    end

    targets = targets.reject {|pod_target| sandbox.local?(pod_target.pod_name) }


    # build!
    Pod::UI.puts "Prebuild frameworks (total #{targets.count})"
    Pod::Prebuild.remove_build_dir(sandbox_path)
    targets.each do |target|
      if !target.should_build?
        UI.puts "Prebuilding #{target.label}"
        next
      end

      output_path = sandbox.framework_folder_path_for_pod_name(target.name)
      output_path.mkpath unless output_path.exist?
      Pod::Prebuild.build(sandbox_path, target, output_path, bitcode_enabled,  Pod::Podfile::DSL.custom_build_options,  Pod::Podfile::DSL.custom_build_options_simulator)

      # save the resource paths for later installing
      if target.static_framework? and !target.resource_paths.empty?
        framework_path = output_path + target.framework_name
        standard_sandbox_path = sandbox.standard_sanbox_path

        resources = begin
                      if Pod::VERSION.start_with? "1.5"
                        target.resource_paths
                      else
                        # resource_paths is Hash{String=>Array<String>} on 1.6 and above
                        # (use AFNetworking to generate a demo data)
                        # https://github.com/leavez/cocoapods-binary/issues/50
                        target.resource_paths.values.flatten
                      end
                    end
        raise "Wrong type: #{resources}" unless resources.kind_of? Array

        path_objects = resources.map do |path|
          object = Pod::Prebuild::Passer::ResourcePath.new
          # object.real_file_path = framework_path + File.basename(path)
          #liuao patch 修改resources的地址  xxx/xxx.framework/ => xxx/
          object.real_file_path = sandbox.framework_folder_path_for_pod_name(target.name) + File.basename(path)
          #liuao patch end
          object.target_file_path = path.gsub('${PODS_ROOT}', standard_sandbox_path.to_s) if path.start_with? '${PODS_ROOT}'
          object.target_file_path = path.gsub("${PODS_CONFIGURATION_BUILD_DIR}", standard_sandbox_path.to_s) if path.start_with? "${PODS_CONFIGURATION_BUILD_DIR}"
          #liuao patch  如果是静态库且framework里没有bundle 从当前沙盒拷贝过去
          realpath = object.target_file_path.gsub('Pods','Pods/_Prebuild')
          if !object.real_file_path.exist? and target.static_framework? and Pathname(realpath).exist?
            # byebug
            FileUtils.cp_r(realpath, object.real_file_path, :remove_destination => true)
          end
          #liuao patch end
          object
        end
        Pod::Prebuild::Passer.resources_to_copy_for_static_framework[target.name] = path_objects
      end
    end
    Pod::Prebuild.remove_build_dir(sandbox_path)

    # copy vendored libraries and frameworks
    targets.each do |target|
      root_path = self.sandbox.pod_dir(target.name)
      target_folder = sandbox.framework_folder_path_for_pod_name(target.name)

      # If target shouldn't build, we copy all the original files
      # This is for target with only .a and .h files
      if not target.should_build?
        Prebuild::Passer.target_names_to_skip_integration_framework << target.pod_name
        FileUtils.cp_r(root_path, target_folder, :remove_destination => true)
        next
      end

      target.spec_consumers.each do |consumer|
        file_accessor = Pod::Sandbox::FileAccessor.new(root_path, consumer)
        lib_paths = file_accessor.vendored_frameworks || []
        lib_paths += file_accessor.vendored_libraries
        # @TODO dSYM files
        lib_paths.each do |lib_path|
          relative = lib_path.relative_path_from(root_path)
          destination = target_folder + relative
          destination.dirname.mkpath unless destination.dirname.exist?
          FileUtils.cp_r(lib_path, destination, :remove_destination => true)
        end
      end
    end

    # Remove useless files
    # remove useless pods
    all_needed_names = self.pod_targets.map(&:name).uniq
    useless_names = sandbox.exsited_framework_names.reject do |name|
      all_needed_names.include? name
    end
    useless_names.each do |name|
      path = sandbox.framework_folder_path_for_pod_name(name)
      path.rmtree if path.exist?
    end

    if not Pod::Podfile::DSL.dont_remove_source_code
      # only keep manifest.lock and framework folder in _Prebuild
      to_remain_files = ["Manifest.lock", File.basename(existed_framework_folder)]
      to_delete_files = sandbox_path.children.select do |file|
        filename = File.basename(file)
        not to_remain_files.include?(filename)
      end
      to_delete_files.each do |path|
        path.rmtree if path.exist?
      end
    else
      # just remove the tmp files
      path = sandbox.root + 'Manifest.lock.tmp'
      path.rmtree if path.exist?
    end

  end

end


def patch_copy_dysms
  puts "copy dysms fixed" .green << "\n"
  def patch(generated_projects)
    generated_projects.each do |project|
        project.targets.each do |target|
          target.shell_script_build_phases.each do |phase|
            script = phase.shell_script
            if script.include? "-copy-dsyms.sh\""
                script = script.delete_prefix "\"${PODS_ROOT}/"
                script = script.delete_suffix "\"\n"
              script = "Pods/" + script
              contents = File.read(script)
              contents = contents.gsub(/-av/, "-r -L -p -t -g -o -D -v")
              File.open(script, "w") do |file|
                file.puts contents
              end
            end
          end
        end
      end
  end

  Pod::Installer.define_method :generate_pods_project do |*args|
    stage_sandbox(sandbox, pod_targets)

    cache_analysis_result = analyze_project_cache
    pod_targets_to_generate = cache_analysis_result.pod_targets_to_generate
    aggregate_targets_to_generate = cache_analysis_result.aggregate_targets_to_generate

    clean_sandbox(pod_targets_to_generate)

    create_and_save_projects(pod_targets_to_generate, aggregate_targets_to_generate,
                              cache_analysis_result.build_configurations, cache_analysis_result.project_object_version)
    patch @generated_projects
    Pod::Installer::SandboxDirCleaner.new(sandbox, pod_targets, aggregate_targets).clean!

    update_project_cache(cache_analysis_result, target_installation_results)
  end

end