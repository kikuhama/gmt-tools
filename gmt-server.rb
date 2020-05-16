# coding: utf-8
require "thread"
require "singleton"
require "securerandom"
require "tmpdir"
require "logger"
require "fileutils"
require "net/http"

class GmtServer
  include Singleton
  API_PREFIX = "/api/v4"

  def initialize
    init
    start
  end

  def init
    log_dir = File.expand_path("../log", __FILE__)
    FileUtils.mkdir_p log_dir
    log_file = File.join(log_dir, "gmt-server.log")
    @logger = Logger.new(log_file)
    @config = GmtToolsConfig.instance
    @job_queue = Queue.new
  end

  def start
    notification = Notification.new
    Thread.new do
      while job = @job_queue.pop
        begin
          notification.mm_direct_message(job[:mm_user_id],
                                         "Job ID: #{job[:id]}の処理を開始します")
          tool = GmtToolsLib.new
          tool.load job
          tool.run
          FileUtils.rm_r job[:work]
          notification.mm_direct_message(job[:mm_user_id],
                                         success_message(job))
        rescue => ex
          notification.mm_direct_message(job[:mm_user_id], ex.message)
          log_error ex
        end
      end
    end
  end

  def push_job(params)
    notification = Notification.new
    begin
      mm = @config.mm_client
      job_id = SecureRandom.uuid
      work_dir = Dir.mktmpdir
      post_id = params[:post_id]
      user_id = params[:user_id]
      user_name = params[:user_name]
      files = mm_files_by_post_id(post_id)
      if files.empty?
        return false
      end

      job_data = mm_get_file(files[0]["id"])
      job = YAML.load(job_data, symbolize_names: true)
      job[:id] = job_id
      job[:mm_user_id] = user_id
      job[:mm_user_name] = user_name
      job[:work] = work_dir
      unless job[:output]
        raise "job yaml file error: :output is not exists"
      end
      job[:output][:dir] = File.join(@config.generated_files_path, job[:id])
      FileUtils.mkdir_p job[:output][:dir]
      @job_queue.push(job)
      notification.mm_direct_message(user_id, "Job ID: #{job_id} が登録されました")
    rescue=> ex
      notification.mm_direct_message(user_id, ex.message)
      log_error ex
    end
  end

  private
  def mm_files_by_post_id(post_id)
    mm = @config.mm_client
    req = mm.get_file_info_for_post(post_id)
    if !req.success?
      raise req.body["message"]
    end
    req.body
  end

  def mm_get_file(file_id)
    access_token = @config.mm_access_token
    uri = URI.parse("#{@config.mm_server}#{API_PREFIX}/files/#{file_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    res = http.get(uri.path, {"Authorization": "Bearer #{access_token}"})
    if res.code != "200"
      raise res.message
    end
    res.body
  end

  def log_error(ex)
    message = "Error: #{ex.message}"
    ex.backtrace.each do |bt|
      message += "\n#{bt}"
    end
    @logger.error message
  end

  def pdf_file(job)
    
  end

  def success_message(job)
    pdf_uri = @config.generated_pdf_file(job[:id])
    eps_uri = @config.generated_eps_file(job[:id])
    msg = <<EOS
Job ID: #{job[:id]} が完了しました。
PDF : #{pdf_uri}
EPS : #{eps_uri}
EOS
  end
end
