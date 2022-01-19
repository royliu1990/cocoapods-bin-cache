require 'cocoapods-binary'
require_relative './cocoapods-binary-patch'
Pod::HooksManager.register('cocoapods-bin-cache', :post_install) do |installer_context|
  if Pod::Podfile::DSL.cache_enabled
    oldmethod = Pod::Prebuild.singleton_method(:build)
    Pod::Prebuild.define_singleton_method :build do |*args|
      target = args[1]
      output_path = args[2]
      prebuild_bin = Pathname(Pod::Podfile::DSL.cache_path + (target.name + target.version + '.zip'))
      if prebuild_bin.exist?
        def extract_zip(file, destination)
          FileUtils.mkdir_p(destination) unless destination.exist?
          `unzip -o #{file} -d #{destination}`
        end
        puts (target.name + ' prebuild cache hit,skip prebuilding🎉🎉') .green << "\n"
        extract_zip(prebuild_bin,output_path)
      else
        puts (target.name + ' has no prebuild cache,start prebuilding🔧🔧') .yellow << "\n"
        oldmethod.call(*args)
        `pushd #{output_path} && zip -r #{prebuild_bin} . && popd`
      end
    end
  end

  if Pod::Podfile::DSL.copy_bunlde_fixed
    patch_copy_bundle
  end

  if Pod::Podfile::DSL.copy_dysms_fixed
    patch_copy_dysms
  end

end


module Pod
  class Podfile
    module DSL
      @@fix_copy_bundle = false
      @@fix_copy_dysms = false
      @@bin_cache_path = nil
      @@enable_prebuild_cache = true
      def self.cache_path
        @@bin_cache_path ||= Pathname(File.expand_path('~') + '/.cocoapods-bin-cache')
        FileUtils.mkdir_p(@@bin_cache_path) unless @@bin_cache_path.exist?
        @@bin_cache_path
      end

      def self.cache_enabled
        @@enable_prebuild_cache
      end

      def self.copy_bunlde_fixed
        @@fix_copy_bundle
      end

      def self.copy_dysms_fixed
        @@fix_copy_dysms
      end

      def enable_bin_cache
        @@enable_prebuild_cache = true
      end

      def disable_bin_cache
        @@enable_prebuild_cache = false
      end

      def fix_copy_bundle
        @@fix_copy_bundle = true
      end

      def fix_copy_dysms
        @@fix_copy_dysms = true
      end


      def set_bin_cache_path(path)
        pathname = Pathname(path)
        raise 'bin_cache_path not exist' unless pathname.exist?
        @@bin_cache_path = pathname
      end
    end
  end
end