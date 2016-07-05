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
  set(:master) {
    c9 = Shangrila::Sora.new().get_map_key_id(2016, 1)
    c10 = Shangrila::Sora.new().get_map_key_id(2016, 2)
    c11 = Shangrila::Sora.new().get_map_key_id(2016, 3)
    c9.update(c10)
    c9.update(c11)
  }

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
  master = settings.master

  ids = params[:ids].split(',')

  start = params[:start]
  end_date = params[:end]

  original_data = nil
  result = []

  DB = db_connection

  if ids != nil
    original_data =  DB[:pixiv_tag_daily].select(:get_date, :bases_id, :total).
        where(:bases_id => ids).
        where("get_date >= ADDDATE(cast(\"#{start}\" as date), INTERVAL -1 DAY)").
        where("get_date <= #{end_date}").
        order(:bases_id).order(:get_date).all
  end

  stuct_data = {}

  original_data.each do |record|
    stuct_data[record[:bases_id]] = [] if stuct_data[record[:bases_id]].nil?
    stuct_data[record[:bases_id]] <<  [record[:get_date].strftime('%Y-%m-%d'), record[:total]]
  end

  stuct_data.each do |key, value|

    up_score = []
    #増減を算出
    value.each_with_index {|v, i|  up_score[i] = [ v[0], v[1] - value[i - 1][1] ]  if i > 0 } # 先頭の１日分データを消す

    result << {
    'name' => master[key]['title'],
    'data' => up_score[1..(up_score.length - 1 )]
    }
  end

  json result
end


#SinatraでCSV
#http://d.hatena.ne.jp/yamamucho/20100614/1276520334
#FIXME データ欠損するとデータがずれるので正確にデータを持つ
get '/data_csv' do
  content_type 'text/csv'
  attachment 'test.csv'

  master = settings.master
  ids = params[:ids].split(',')

  start = params[:start]
  end_date = params[:end]

  original_data = nil

  DB = db_connection

  if ids != nil
    original_data =  DB[:pixiv_tag_daily].select(:get_date, :bases_id, :total).
        where(:bases_id => ids).
        where("get_date >= ADDDATE(cast(\"#{start}\" as date), INTERVAL -1 DAY)").
        where("get_date <= #{end_date}").
        order(:bases_id).order(:get_date).all
  end

  struct_data = {}

  original_data.each do |record|
    struct_data[record[:bases_id]] = {} if struct_data[record[:bases_id]].nil?

    struct_data[record[:bases_id]][record[:get_date]] = record[:total]
  end

  struct_data2 = {}

  struct_data.each do |key, value|

    struct_data2[key] = {} if struct_data2[key].nil?

    value.each {|date, total|

      before_score = struct_data[key][date - (24 * 60 * 60)]

      if before_score.nil?
        struct_data2[key][date] = total
      else
        struct_data2[key][date] = total - struct_data[key][date - (24 * 60 * 60)]
      end

    }
  end

  csv_data = {}
  #１列目1行目
  csv_string = ''
  struct_data2.each{|key, value|
    csv_string +=',' #1行目1列目は空
    csv_string = csv_string + master[key]['title']

    value.each do |k, v|
      csv_data[k]  = [] if csv_data[k].nil?
      csv_data[k] << v
    end
  }
  csv_string += "\n"

  first = true
  csv_data.each{|key, value|
    #先頭の１行目はださない
    csv_string = csv_string + key.strftime("%Y-%m-%d") + ',' + value.join(',') + "\n" if first == false
    first = false
  }

  #for Excel
  csv_string.encode("Shift_JIS", "UTF-8" , :undef => :replace, :replace => ' ')

end
