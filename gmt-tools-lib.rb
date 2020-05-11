require "fileutils"
require "logger"
require "gmt-tools-config"

class GmtToolsLib
  def initialize(data_file)
    @config = GmtToolsConfig.instance
    data = YAML.load(IO.read(data_file), symbolize_names: true)
    @modified_at = File.mtime(data_file)
    @dir = File.dirname(File.absolute_path(data_file))
    @data = data
    @work_dir = File.expand_path(@data[:work])
    @output_dir = File.expand_path(@data[:output][:dir])
    @dem_file = File.join(@work_dir, "dem.nc")
    @grad_file = File.join(@work_dir, "dem-grad.nc")
    @palet_file = File.join(@work_dir, "palet.cpt")
    @log_file = File.join(@work_dir, "gmt-tools.log")
    make_work_dir
    basename = @data[:output][:basename]
    @eps_file = File.join(@output_dir, basename + ".eps")
    @pdf_file = File.join(@output_dir, basename + ".pdf")
    @gmt = File.join(@config.gmt_path, "gmt")
  end

  def run
    if File.exists?(@eps_file)
      File.delete @eps_file
    end
    if File.exists?(@pdf_file)
      File.delete @pdf_file
    end

    Dir.chdir(@work_dir) do
      @data[:commands].each_index do |idx|
        cmd = @data[:commands][idx]
        opts = [@data[:misc]]
        if idx < @data[:commands].size - 1
          opts << "-K"
        end
        if idx > 0
          opts << "-O"
        end
        
        case cmd[:cmd]
        when "grdview"
          cmd_grdview opts
        end
      end
      make_pdf
    end
  end

  private
  def cmd_grdview(opts = [])
    make_dem
    opts_str = opts.join(" ")
    cmd = <<EOS
#{@gmt} grdview #{@dem_file} -I#{@grad_file} #{gmt_range} #{gmt_proj_method} #{gmt_sea_level} #{gmt_color_palet} #{gmt_z_scale} #{gmt_viewpoint} #{gmt_resolution} #{opts_str} >> #{@eps_file}
EOS
    exec_cmd cmd
  end

  def gmt_range
    n = @data[:range][:north]
    s = @data[:range][:south]
    w = @data[:range][:west]
    e = @data[:range][:east]
    "-R#{w}/#{e}/#{s}/#{n}"
  end

  def gdal_projwin
    n = @data[:range][:north]
    s = @data[:range][:south]
    w = @data[:range][:west]
    e = @data[:range][:east]
    "-projwin #{w} #{n} #{e} #{s}"
  end

  def gmt_proj_method
    method = @data[:projection][:method]
    size = @data[:projection][:size]
    "-J#{method}#{size}"
  end

  def gmt_sea_level
    sea_level = @data[:sea_level]
    sea_level ? "-N#{sea_level}" : ""
  end

  def gmt_color_palet
    "-C#{@palet_file}"
  end

  def gmt_z_scale
    birdview? ? "-JZ#{@data[:z_scale]}" : ""
  end

  def gmt_viewpoint
    birdview? ? "-p#{@data[:viewpoint]}" : ""
  end

  def birdview?
    @data[:birdview] === true
  end

  def gmt_resolution
    @data[:resolution] > 0 ? "-Qi#{@data[:resolution]}" : ""
  end

  def gdal_dem_db_str
    case @data[:dem]
    when "dem10"
      db_str = @config.gdal_db_dem10
    else
      raise "Invalid dem setting: #{@data[:dem]}"
    end
    db_str
  end
  
  def make_dem
    if !File.exists?(@dem_file) || File.mtime(@dem_file) < @modified_at
      # create dem file
      db_str = gdal_dem_db_str
      gdal_translate = gdal_cmd("gdal_translate")
      cmd = "#{gdal_translate} -of GMT #{gdal_projwin} \"#{db_str}\" #{@dem_file}"
      exec_cmd cmd
    end
    make_dem_grad
  end

  def make_dem_grad
    unless File.exists?(@dem_file)
      raise "dem file not exists"
    end
    if !File.exists?(@grad_file) || File.mtime(@grad_file) < File.mtime(@dem_file)
      # create grad file
      azim = "-A#{@data[:gradient][:azim]}"
      norm = "-N#{@data[:gradient][:normalization]}"
      cmd = "#{@gmt} grdgradient #{@dem_file} -G#{@grad_file} #{azim} #{norm}"
      exec_cmd cmd
    end
  end

  def make_pdf
    resolution = @data[:resolution] ? @data[:resolution] : 300
    convert = imagemagick_cmd("convert")
    cmd = "convert -density #{resolution} #{@eps_file} #{@pdf_file}"
    exec_cmd cmd
  end

  def make_work_dir
    STDERR.print "work_dir: #{@work_dir}\n"
    FileUtils.mkdir_p @work_dir
    @logger = Logger.new(@log_file)
    gmt_config = @config.gmt_config_file
    work_gmt_config = File.join(@work_dir, "gmt.conf")
    if File.exists?(gmt_config) && !File.exists?(work_gmt_config)
      FileUtils.cp gmt_config, work_gmt_config
    end
    IO.write(@palet_file, @data[:palet])
  end

  def gdal_cmd(cmd)
    File.join(@config.gdal_path, cmd)
  end

  def imagemagick_cmd(cmd)
    File.join(@config.imagemagick_path, cmd)
  end
  
  def exec_cmd(cmd)
    message = "Exec: #{cmd}"
    @logger.info message
    STDERR.print message + "\n"
    begin
      `#{cmd}`
    rescue => ex
      log_error ex
      raise ex
    end
  end

  def log_error(ex)
    message = ex.message
    ex.backtrace.each do |bt|
      message += "\n#{bt}"
    end
    @logger.error "Error: #{message}"
  end
end
