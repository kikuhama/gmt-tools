require "yaml"
require "singleton"
require "mattermost"

class GmtToolsConfig
  include Singleton
  
  CONFIG_FILE = File.expand_path("../config.yaml", __FILE__)

  def initialize
    load
  end

  def gdal_db_dem10
    gdal_db_str @config[:db][:dem10], {mode: 2}
  end

  def gdal_db_srtm3
    gdal_db_str @config[:db][:srtm3], {mode: 2}
  end

  def gdal_db_gebco
    gdal_db_str @config[:db][:gebco], {mode: 2}
  end

  def gdal_db_str(table, opts = {})
    host = @config[:db][:host]
    db = @config[:db][:database]
    user = @config[:db][:user]
    password = @config[:db][:password]
    opt_str = opts.keys.map{|k| "#{k}=#{opts[k]}"}.join(" ")
    "PG:host=#{host} dbname=#{db} table=#{table} user=#{user} password=#{password} #{opt_str}"
  end

  def gmt_config_file
    File.expand_path("../gmt.conf", __FILE__)
  end

  def gdal_path
    @config[:path][:gdal].to_s
  end

  def gmt_path
    @config[:path][:gmt].to_s
  end

  def imagemagick_path
    @config[:path][:imagemagick].to_s
  end

  def ghostscript_path
    @config[:path][:ghostscript].to_s
  end

  def generated_files_path
    @config[:path][:generated_files].to_s
  end

  def mm_client
    mm = Mattermost.new_client(@config[:mattermost][:server])
    mm.use_access_token(@config[:mattermost][:access_token])
    mm
  end

  def mm_server
    @config[:mattermost][:server]
  end

  def mm_access_token
    @config[:mattermost][:access_token]
  end

  def generated_pdf_file(job_id)
    @config[:download][:base_uri] + "/file/#{job_id}.pdf" 
  end

  def generated_eps_file(job_id)
    @config[:download][:base_uri] + "/file/#{job_id}.eps" 
  end

  private
  def load
    @config = {
      db: {
        host: "localhost",
        database: "gis",
        user: "gis",
        password: "",
        dem10: "dem10",
      },
    }
    
    if File.exists?(CONFIG_FILE)
      data = YAML.load(IO.read(CONFIG_FILE), symbolize_names: true)
      @config.merge!(data)
    end
  end
end
