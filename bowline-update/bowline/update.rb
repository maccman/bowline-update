require "thread"
require "versionomy"
require "restclient"
require "tmpdir"
require "zip/zip"
require "json"

module Bowline
  module Update
    UPDATE_PATH = File.join(Desktop::Path.user_data, "update")
    EXE_UPDATE_PATH = File.join(UPDATE_PATH, "bowline-desktop")
  
    def update!
      return unless File.dir?(UPDATE_PATH)
      if File.exist?(EXE_UPDATE_PATH)
        FileUtils.mv(EXE_UPDATE_PATH, Desktop::Path.raw_exe)
      end
      FileUtils.rm_rf(APP_ROOT)
      FileUtils.mv(UPDATE_PATH, APP_ROOT)
      restart!
    end
  
    def check(*args)
      update!
      Thread.new do
        check_without_thread(*args)
      end
    end
  
    def check_without_thread(url, current)
      begin
        result  = RestClient.get(url, :platform => Platform.type, :accept => :json)
      rescue SocketError, RestClient::Exception
        return
      end
      return if result.length == 0
      result  = JSON.parse(result)
      current = Versionomy.parse(current)
      version = Versionomy.parse(result[:version])
      if version > current
        download(result)
      end
    end
  
    private
      def download(result)
        response = RestClient.get(result[:url], :raw_response => true)
        # verify(file, result[:dsa_signature])
        download_dir = Dir.mktmpdir
        unzip(result.file.path, download_dir)
        FileUtils.mv(download_dir, UPDATE_PATH)
      end  
  
      def restart!
        exe  = Desktop::Path.exe
        args = ARGV
        fork do
          sleep 1
          system(exe, *args)
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
  
    extend self
  end
end