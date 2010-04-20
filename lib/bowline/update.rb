require "thread"
require "versionomy"
require "nestful"
require "fileutils"
require "tmpdir"
require "zip/zip"
require "json"

module Bowline
  module Update
    extend Bowline::Logging
    
    BACKUP = {:osx => %w{English.lproj}}
  
    def check(*args)
      return unless Desktop.enabled?
      update!
      Thread.new do
        check_without_thread(*args)
      end
    end
  
    def check_without_thread(url, current, params = {})
      trace "Bowline Update - checking #{url}"
      
      params.merge!({
        :platform => Platform.type,
        :version  => current
      })
      
      result  = Nestful.json_get(url, params)
      current = Versionomy.parse(current)
      version = Versionomy.parse(result["version"])
      if version > current
        download(result)
      end
    rescue => e
      log_error(e)
    end
    
    def update!
      return unless File.directory?(update_path)
      trace "Bowline Update - updating!"
      update_exe
      backup_app
      update_app
      restart!
    end
  
    private
      def update_exe
        if File.exist?(exe_update_path)
          FileUtils.mv(exe_update_path, Desktop::Path.raw_exe)
        end
      end
      
      def backup_app
        backups = BACKUP[Platform.type]
        return unless backups
        FileUtils.cd(APP_ROOT) do
          FileUtils.mv(backups, update_path)
        end
      end
      
      def update_app
        FileUtils.rm_rf(APP_ROOT)
        FileUtils.mv(update_path, APP_ROOT)
      end
    
      def download(result)
        trace "Bowline Update - downloading #{result["url"]}"
        response = Nestful.get(result["url"], :buffer => true)
        download_dir = Dir.mktmpdir
        trace "Bowline Update - unzipping"
        unzip(response.path, download_dir)
        FileUtils.mv(download_dir, update_path)
      end  
  
      def restart!
        exe_path = Desktop::Path.raw_exe
        fork do
          system(exe_path, APP_ROOT)
        end
        exit!
      end
    
      def unzip(fpath, tpath)
        Zip::ZipFile.open(fpath) { |zfile|
          zfile.each {|file|
            file_path = File.join(tpath, file.name)
            FileUtils.mkdir_p(File.dirname(file_path))
            zfile.extract(file, file_path)
          }
        }
      end
      
      def update_path
        File.join(Desktop::Path.user_data, "app_update")
      end
      
      def exe_update_path
        File.join(update_path, "bowline-desktop")
      end
    extend self
  end
end