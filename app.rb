# :)

require 'sinatra'
require 'sinatra/activerecord'
require 'haml'
require 'sass'
require 'open-uri'
require './lib/peakjohn'

ENV["DATABASE_URL"] ||= "sqlite3:database.sqlite"

class PeakJohn < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  set :database, ENV["DATABASE_URL"]

  helpers do
    def app_root
      "#{env["rack.url_scheme"]}://#{env["HTTP_HOST"]}#{env["SCRIPT_NAME"]}"
    end
    
    def archive_base
      "http://dbarchive.biosciencedbc.jp/kyushu-u/"
    end
    
    def igv_browsing_url(data)
      igv_url   = data["igv"] || "http://localhost:60151"
      condition = data["condition"]
      genome    = condition["genome"]
      filename  = Bedfile.get_filename(condition)
    
      archive_path = File.join(archive_base, genome, "assembled", filename)
      "#{igv_url}/load?genome=#{genome}&file=#{archive_path}"
    end
  end
  
  get "/:source.css" do
    sass params[:source].intern
  end
  
  get "/" do
    haml :index
  end
  
  get "/index" do
    genome = params[:genome]
    404 if !Bedfile.list_of_genome.include?(genome)
    JSON.dump(Bedfile.index_by_genome(genome))
  end
  
  post "/browse" do
    JSON.dump({ "url" => igv_browsing_url(JSON.parse(request.body.read)) })
  end
  
  get "/view" do
    params[:id]
  end
end
