require 'open-uri'
require 'net/http'

module PJ
  class FastQC
    class << self
      def domain
        "data.dbcls.jp"
      end

      def path
        "/~inutano/fastqc"
      end

      def base
        "http://#{domain}/#{path}"
      end

      def get_images_url(exp_id, app_root)
        run_ids = PJ::Run.exp2run(exp_id)
        run_ids.map{|runid| PJ::FastQC.new(runid, app_root).images_url }.flatten
      end
    end

    def initialize(run_id, app_root)
      @run_id = run_id
      @fpath = File.join(run_id.slice(0,3), run_id.slice(0,4), run_id.sub(/...$/,""), run_id)
      @app_root = app_root
    end

    def images_url
      published_images
      # Comment out above and uncomment below to fetch data from data.dbcls.jp
      # fetch if !cached?
      # cached_images
    end

    def published_images_path
      ["", "_1", "_2"].map do |sfx|
        File.join(
          "http://sra.dbcls.jp/fastqc",
          @run_id.slice(0,3),
          @run_id.slice(0,4),
          @run_id.sub(/...$/,""),
          @run_id,
          @run_id + sfx,
          @run_id + sfx + "_fastqc",
          "Images",
          "per_base_quality.png"
        )
      end
    end

    def published_images
      published_images_path.select{|url| Net::HTTP.get_response(URI.parse(url)).code == "200" }.compact
    end

    def read_quality_dir
      fetch if !cached?
      local_dir_url
    end

    def remote_run_dir
      File.join(PJ::FastQC.fastqc_base, @fpath)
    end

    def project_root
      File.join(File.dirname(__FILE__), "..", "..")
    end

    def local_run_dir
      File.join(project_root, "public/images/fastqc", @fpath)
    end

    def reads_suffix
      ["_fastqc","_1_fastqc","_2_fastqc"]
    end

    def local_images_url
      reads_suffix.map do |read|
        File.join(@app_root, "images/fastqc", @fpath, @run_id+read, "Images", "per_base_quality.png")
      end
    end

    def local_dir_url
      reads_suffix.map do |read|
        File.join(@app_root, "images/fastqc", @fpath, @run_id+read)
      end
    end

    def cached?
      status_list = local_images_url.map do |url|
        uri = URI(url)
        request = Net::HTTP.new(uri.host, uri.port)
        response = request.request_head(uri.path)
        response.code.to_i
      end
      status_list.include?(200)
    end

    def cached_images
      local_images_url.select{|url| remotefile_available?(url) }
    end

    def remotefile_available?(url)
      uri = URI(url)
      request = Net::HTTP.new(uri.host, uri.port)
      response = request.request_head(uri.path)
      response.code.to_i == 200
    end

    def fetch
      FileUtils.mkdir_p(local_run_dir) if !File.exist?(local_run_dir)
      Net::HTTP.start(PJ::FastQC.domain) do |http|
        reads_suffix.each do |suffix|
          read_fname = @run_id + suffix + ".zip"
          resp = http.get(File.join(PJ::FastQC.path, @fpath, read_fname))
          open(File.join(local_run_dir,read_fname), "wb") do |file|
            file.write(resp.body)
          end
        end
      end
      `unzip -d "#{local_run_dir}" "#{local_run_dir}/*zip"`
    end
  end
end
