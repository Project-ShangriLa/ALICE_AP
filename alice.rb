require 'sinatra'
require 'haml'
require 'shangrila'
require 'sequel'
require "sinatra/json"


#TODO DB接続情報は設定ファイルに書く
configure do
  # 静的コンテンツ参照のためのパス設定
  set :public, File.dirname(__FILE__) + '/public'

  puts "-------LOAD-------"
  set(:master) { Shangrila::Sora.new().get_map_key_id(2016, 1) }

  set(:database_name) { 'anime_admin_development' }
  set(:database_hostname) { 'localhost' }
  set(:database_username) { 'root' }
  set(:database_password) { '' }
  set(:database_port) { '3306' }
end

def db_connection()
  Sequel.mysql2(settings.database_name,
                :host=>settings.database_hostname,
                :user=>settings.database_username,
                :password=>settings.database_password,
                :port=>settings.database_port)
end


get '/data_json' do
  @master = settings.master
  @ids = params[:ids].split(',')

  @start = params[:start]
  @end = params[:end]


  @result = nil

  DB = db_connection


  ##TODO Daily増加分の計算

  if @ids != nil
    @result =  DB[:pixiv_tag_daily].where(:bases_id => @ids).all
  end

  json @result
end


#SinatraでCSV
#http://d.hatena.ne.jp/yamamucho/20100614/1276520334
#FIXME データ欠損するとデータがずれるので正確にデータを持つ
get '/data_csv' do
  content_type 'text/csv'
  attachment 'test.csv'

  @master = settings.master
  @ids = params[:ids].split(',')

  @start = params[:start]
  @end = params[:end]


  @original_data = nil
  @result = nil

  DB = db_connection

  if @ids != nil
    @original_data =  DB[:pixiv_tag_daily].select(:get_date, :bases_id, :total).
        where(:bases_id => @ids).
        where("get_date >= ADDDATE(cast(\"#{@start}\" as date), INTERVAL -1 DAY)").
        where("get_date <= #{@end}").
        order(:bases_id).all
  end

  title_base_data = {}
  stuct_data = {}

  @original_data.each do |record|
    title_base_data[record[:bases_id]] = [] if title_base_data[record[:bases_id]] == nil
    title_base_data[record[:bases_id]] = nil

    stuct_data[record[:bases_id]] = {} if stuct_data[record[:bases_id]].nil?

    stuct_data[record[:bases_id]][record[:get_date]] = record[:total]
  end

  #Daily増加分の計算
  csv_data = {}
  @original_data.each do |record|
    csv_data[record[:get_date]] = [] if csv_data[record[:get_date]] == nil

    before_score = stuct_data[record[:bases_id]][record[:get_date] - (24 * 60 * 60)]

    if before_score.nil?
      csv_data[record[:get_date]] << record[:total]
    else
      csv_data[record[:get_date]] << record[:total] - before_score
    end

  end

  #1行目
  csv_string = ''
  title_base_data.each{|key, value|
    csv_string +=',' #1行目1列目は空
    csv_string = csv_string + @master[key]['title']
  }
  csv_string += "\n"

  first = true
  csv_data.each{|key, value|
    csv_string = csv_string + key.strftime("%Y-%m-%d") + ',' + value.join(',') + "\n" if first == false
    first = false
  }

  #for Excel
  csv_string.encode("Shift_JIS", "UTF-8")

end
