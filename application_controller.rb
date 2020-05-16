# coding: utf-8
class ApplicationController < Sinatra::Base
  helpers Sinatra::JSON

  configure do
  end

  configure :development do
    register Sinatra::Reloader
  end

  post "/job" do
    server = GmtServer.instance
    server.push_job(params)
  end

  get "/file/*.*" do |job_id, ext|
    config = GmtToolsConfig.instance
    dir = File.join(config.generated_files_path, job_id)
    STDERR.print dir + "\n"
    mask = dir + "/*.#{ext}"
    files = Dir.glob(mask)
    if files.empty?
      halt 404, "No files generated"
    end
    file = files[0]
    if !File.exists? file
      halt 404, "File not found (#{file})"
    end
    send_file file, :disposition => :attachment
  end
end
