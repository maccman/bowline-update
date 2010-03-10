require "thread"
require "versionomy"
require "restclient"
require "fileutils"
require "tmpdir"
require "zip/zip"
require "json"

module Bowline
  module Update
    BACKUP = {:osx => %w{English.lproj}}
  
    def check(*args)
      return unless Desktop.enabled?
      update!
      Thread.new do
        check_without_thread(*args)
      end
    end
  
    def check_without_thread(url, current)
      begin
        result = RestClient.get(url, :platform => Platform.type, :accept => :json)
      rescue => e
        Bowline::Logging.log_error(e)
        return
      end
      return if result.body.length == 0
      result  = JSON.parse(result.body)
      current = Versionomy.parse(current)
      version = Versionomy.parse(result[:version])
      if version > current
        download(result)
      end
    end
    
    def update!
      return unless File.directory?(update_path)
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
        backups = BACKUPS[Platform.type]
        return unless backups
        FileUtils.cd(APP_ROOT) do
          FileUtils.mv_r(backups, update_path)
        end
      end
      
      def update_app
        FileUtils.rm_rf(APP_ROOT)
        FileUtils.mv(update_path, APP_ROOT)
      end
    
      def download(result)
        response = RestClient.get(result[:url], :raw_response => true)
        download_dir = Dir.mktmpdir
        unzip(response.file.path, download_dir)
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