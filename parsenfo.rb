#!/usr/bin/ruby -w
#: Title		: parsenfo.rb (Parse NFO)
#: Date			: 2010-06-22
#: Author		: "Eugene Fokin" <ginfonic@gmail.com>
#: Version		: 3.1
#: Description	: Parses text file with tagged CD records info
#: Description	: into CSV or tab delimited text file or to SQLite3 database.
#: Arguments	: [-options] input_file|input_folder [output_file]
#
require "rubygems"
require "sqlite3"
#InOut class for parsing arguments, getting strings from text file, storing track records of all albums
#& putting them to CSV or tab delimited text file or to SQLite3 database.
class InOut
  IN_FILE_EXT = ".txt"
  OUT_LOG_FILE_NAME = "parsenfo"
  LOG_FILE_EXT = ".log"
  INFO = %q{
parsenfo.rb # version: 3.1 # date: 2010-06-22
created by: eugene fokin <ginfonic@gmail.com>
description: parses text file with tagged cd records info
  into CSV or tab delimited text file or to sqlite3 database

usage: parsenfo.rb [-options] input_file|input_folder [output_file]

options: -fvctl
  f: creates log file parcenfo.log in script folder (default)
  v: verbose mode, creates no log file
  c: output file kind -- CSV, extention -- .csv (default)
  t: output file kind -- tab delimited text, extention -- .txt
  c: output file kind -- sqlite3 database, extention -- .db
input_file: nfo text file with tagged cd records info
input_folder: folder with these files:
  .txt extention, no recursing
output_file: file for storing parsed cd records info:
  by default has name parsenfo,
  extention corresponded to selected kind of output file
  and stored into folder with input_file

Please, select input file or folder!}
  attr_reader :log_kind, :out_file_kind, :log_file, :in_files, :out_file, :log_lines, :out_items
  #Initializes class with kind of output file, log mode, input & output files.
  def initialize(options, in_file, out_file)
    #Defaults values of kind of log, kind & extention of output file.
    @log_kind, @out_file_kind, out_file_ext = :file, :csv, ".csv"
    #Defines array of output items for storing track records of all albums.
    @out_items = []
    #Defines kind of log (text file or verbose) & output file (CSV, tab delimited or SQLite3).
    options_a = options.to_s.split(//)
    if options_a.shift == "-"
      options_a.each do |option|
        case option
        when "f"
          @log_kind = :file
        when "v"
          @log_kind = :verbose
        when "c"
          @out_file_kind, out_file_ext = :csv, ".csv"
        when "t"
          @out_file_kind, out_file_ext = :tab, ".txt"
        when "l"
          @out_file_kind, out_file_ext = :sqlite3, ".db"
        end
      end
    else
      out_file, in_file = in_file, options
    end
    #Defines input files.
    #Extention of input files.
    #Array of input files.
    @in_files = []
    if in_file.nil?
    #If in_file is folder gets all files from it.
    elsif File.directory?(in_file)
      @in_files = Dir["#{in_file}/*#{IN_FILE_EXT}"]
    #If in_file is file, exists and of right kind add it to array.
    elsif File.exist?(in_file) && File.extname(in_file) == IN_FILE_EXT
      @in_files << in_file
    end
    #Exits with message if no input files.
    if @in_files.empty?
      puts INFO
      exit
    end
    #Defines output file.
    #If out_file is not selected defaults it.
    if out_file.nil?
      @out_file = "#{File.dirname(@in_files.first)}/#{OUT_LOG_FILE_NAME}#{out_file_ext}"
    #If out_file have no full path store it in folder with first in_file.
    elsif File.dirname(out_file) == "."
      @out_file = "#{File.dirname(@in_files.first)}/#{out_file}#{out_file_ext if File.extname(out_file).empty?}"
    else
      @out_file = "#{out_file}#{out_file_ext if File.extname(out_file).empty?}"
    end
    #Defines log file.
    @log_file = "#{File.dirname(__FILE__)}/#{OUT_LOG_FILE_NAME}#{LOG_FILE_EXT}"
    #Defines array of log lines.
    @log_lines = ["##### parsenfo.rb log file created at #{Time.now} #####\n##### output file: #{@out_file} #####"]
  end
  #Gets strings from each input file to array and calls external block to treat it.
  #Result of calling (track records of album) adds to array of output items.
  def get_each
    @in_files.each do |in_file|
      lines = []
      File.foreach(in_file) {|line| lines << line.chomp}
      album_items = yield lines
      if !album_items.empty?
        to_log(album_items) 
        @out_items += album_items
      end
    end
  end
  #Converts array of track records to array of CSV records.
  def to_csv_lines(items)
    require "csv"
    lines = []
    items.each {|item| lines << CSV.generate_line(item)}
    lines
  end
  #Converts array of track records to array of tab delimited records.
  def to_tab_lines(items)
    lines = []
    items.each do |raw|
      line = ""
      raw.each {|record| line += "#{record}\t"}
      lines << line.slice(0, line.length - 1)
    end
    lines
  end
  #Converts array of track records to array of hashes of track records.
  def to_hashes(items)
    hashes = []
    items.each do |item|
      hashes << {:codec => item[0], :album_artist_name => item[1], :album_title => item[2], :year => item[3],
        :publisher => item[4], :genre => item[5], :style => item[6], :comment => item[7],
        :disc_number => item[8], :disc_title => item[9], :track_number => item[10],
        :track_artist_name => item[11], :track_title => item[12], :composer => item[13]}
    end
    hashes
  end
  def to_log(items)
    log_line = "#{log_lines.length}: #{items[0][1]} - #{items[0][2]}"
    puts log_line if log_kind == :verbose
    log_lines << log_line
  end
  #Puts array of track records to output file.
  def put
    if @out_file_kind == :sqlite3
      db = SQLite3::Database.new(@out_file)
      sqlite3_query = SQLite3Query.new(db, to_hashes(@out_items))
      sqlite3_query.insert_records
      db.close
    else
      lines = if @out_file_kind == :tab then to_tab_lines(@out_items)
      else to_csv_lines(@out_items) end
      File.open(@out_file, "a") {|fp| fp.puts lines}
    end
    #Puts log lines to log file.
    File.open(@log_file, "a") {|fp| fp.puts @log_lines} if @log_kind == :file
  end
end
#Info class for parsing data from input array.
class Info
  attr_reader :codec, :album_artist_name, :album_title, :year, :publisher, :genre, :style, :comment,
    :track_counts, :disc_titles, :track_artist_names, :track_titles, :composers
  #Parses data from input array.
  def initialize(lines)
    @track_counts, @disc_titles, @track_artist_names, @track_titles, @composers = [], [], [], [], []
    lines.each do |line|
      #Finds tag name in string.
      tag_end = line.index("=")
      #Rejects empty lines & lines with no tag name.
      next if line.empty? || tag_end.nil?
      #Detaches tag name.
      tag = line.slice!(0, tag_end + 1)
      #Fills values based on tag names.
      case tag.slice(0, 3)
      when "COD"
        @codec = line
      when "ART"
        @album_artist_name = line
      when "ALB"
        @album_title = line
      when "YEA"
        @year = line
      when "PUB"
        @publisher = line
      when "GEN"
        @genre = line
      when "STY"
        @style = line
      when "CMT"
        @comment = line
      when "MTC"
        @track_counts << line
      when "MAL"
        @disc_titles << line
      when "TAR"
        @track_artist_names << line
      when "TRA"
        @track_titles << line
      when "CMP"
        @composers << line
      end
    end
  end
end
#Album class with tree of arrays (Disc, Track structures) for storing data from Info object.
class Album
  #Types.
  Disc = Struct.new(:disc_number, :disc_title, :tracks)
  Track = Struct.new(:track_number, :track_artist_name, :track_title, :composer)
  #Attributes.
  attr_reader :codec, :album_artist_name, :album_title, :year, :publisher, :genre, :style, :comment, :discs
  #Methods.
  #Fills tree of arrays with data from Info object.
  def initialize(info)
    @codec, @album_artist_name, @album_title, @year, @publisher, @genre, @style, @comment, @discs =
      info.codec, info.album_artist_name, info.album_title, info.year,
      info.publisher, info.genre, info.style, info.comment, []
    #Number of discs is equal number of tags MTC plus 1.
    disc_count = info.track_counts.length + 1
    i = j = 0
    while disc_count > i
      #Creates new disc.
      disc = Disc.new((i + 1).to_s, info.disc_titles[i], [])
      #Number of tracks of current disc is whether stored in MTC tag of this disc
      #or (for last disc) is calculated as number of all track of album minus sum of all MTS tags.
      track_count = info.track_counts[i].nil? ?
        info.track_titles.length - info.track_counts.inject {|sum, n| sum.to_i + n.to_i}.to_i :
        info.track_counts[i].to_i
      k = 0
      while track_count > k
        #Creates & adds new track.
        track = Track.new((k + 1).to_s, info.track_artist_names[j], info.track_titles[j], info.composers[j])
        disc.tracks << track
        j += 1
        k += 1
      end
      #Adds new disc.
      @discs << disc
      i += 1
    end
  end
  #Fills empty records (disc_title, track_artist_name & composer) by default.
  def default
    @discs.each do |disc|
      if disc.disc_title.nil?
        disc.disc_title = @discs.length > 1 ? "#{@album_title} CD#{disc.disc_number}" : @album_title
      end
      disc.tracks.each do |track|
        track.track_artist_name = @album_artist_name if track.track_artist_name.nil?
        if track.composer.nil?
          if !@discs.first.tracks.first.composer.nil? then track.composer = @discs.first.tracks.first.composer
          else track.composer = track.track_artist_name end
        end
      end
    end
    self
  end
  #Converts tree of arrays to array of track records.
  def to_items
    items = []
    @discs.each do |disc|
      disc.tracks.each do |track|
        items << [@codec, @album_artist_name, @album_title, @year, @publisher, @genre, @style, @comment,
          disc.disc_number, disc.disc_title, track.track_number, track.track_artist_name, track.track_title, track.composer]
      end
    end
    items
  end
end
#SQLite3Query class for creating and inserting records into SQLite3 database.
class SQLite3Query
  #Types.
  Column = Struct.new(:header, :tycon)
  Table = Struct.new(:header, :constraint, :columns)
  #Constants.
  NULL = "NULL"
  #Column definitions.
  ID_COLUMN = Column.new("id", "INTEGER PRIMARY KEY AUTOINCREMENT")
  ALBUM_ARTIST_ID_COLUMN = Column.new("album_artist_id", "INTEGER")
  ALBUM_TITLE_COLUMN = Column.new("album_title", "TEXT")
  YEAR_COLUMN = Column.new("year", "TEXT")
  PUBLISHER_ID_COLUMN = Column.new("publisher_id", "INTEGER")
  CODEC_ID_COLUMN = Column.new("codec_id", "INTEGER")
  STYLE_1_ID_COLUMN = Column.new("style_1_id", "INTEGER")
  STYLE_2_ID_COLUMN = Column.new("style_2_id", "INTEGER")
  STYLE_3_ID_COLUMN = Column.new("style_3_id", "INTEGER")
  STYLE_4_ID_COLUMN = Column.new("style_4_id", "INTEGER")
  STYLE_5_ID_COLUMN = Column.new("style_5_id", "INTEGER")
  COMMENT_COLUMN = Column.new("comment", "TEXT")
  DISC_NUMBER_COLUMN = Column.new("disc_number", "TEXT")
  DISC_TITLE_COLUMN = Column.new("disc_title", "TEXT")
  ALBUM_ID_COLUMN = Column.new("album_id", "INTEGER")
  TRACK_NUMBER_COLUMN = Column.new("track_number", "TEXT")
  TRACK_ARTIST_ID_COLUMN = Column.new("track_artist_id", "INTEGER")
  TRACK_TITLE_COLUMN = Column.new("track_title", "TEXT")
  DISC_ID_COLUMN = Column.new("disc_id", "INTEGER")
  ARTIST_NAME_COLUMN = Column.new("artist_name", "TEXT UNIQUE")
  PUBLISHER_COLUMN = Column.new("publisher", "TEXT UNIQUE")
  CODEC_COLUMN = Column.new("codec", "TEXT UNIQUE")
  STYLE_COLUMN = Column.new("style", "TEXT UNIQUE")
  #Table definitions.
  ARTISTS_TABLE = Table.new("artists", nil, [ID_COLUMN, ARTIST_NAME_COLUMN])
  PUBLISHERS_TABLE = Table.new("publishers", nil, [ID_COLUMN, PUBLISHER_COLUMN])
  CODECS_TABLE = Table.new("codecs", nil, [ID_COLUMN, CODEC_COLUMN])
  STYLES_TABLE = Table.new("styles", nil, [ID_COLUMN, STYLE_COLUMN])
  ALBUMS_TABLE = Table.new("albums", "UNIQUE (#{ALBUM_ARTIST_ID_COLUMN.header}, #{ALBUM_TITLE_COLUMN.header})",
    [ID_COLUMN, ALBUM_ARTIST_ID_COLUMN, ALBUM_TITLE_COLUMN, YEAR_COLUMN, PUBLISHER_ID_COLUMN, CODEC_ID_COLUMN,
    STYLE_1_ID_COLUMN, STYLE_2_ID_COLUMN, STYLE_3_ID_COLUMN, STYLE_4_ID_COLUMN, STYLE_5_ID_COLUMN, COMMENT_COLUMN])
  DISCS_TABLE = Table.new("discs", "UNIQUE (#{DISC_NUMBER_COLUMN.header}, #{ALBUM_ID_COLUMN.header})",
    [ID_COLUMN, DISC_NUMBER_COLUMN, DISC_TITLE_COLUMN, ALBUM_ID_COLUMN])
  TRACKS_TABLE = Table.new("tracks", "UNIQUE (#{TRACK_NUMBER_COLUMN.header}, #{DISC_ID_COLUMN.header})",
    [ID_COLUMN, TRACK_NUMBER_COLUMN, TRACK_ARTIST_ID_COLUMN, TRACK_TITLE_COLUMN, DISC_ID_COLUMN])
  #Database definition.
  TABLES = [ARTISTS_TABLE, PUBLISHERS_TABLE, CODECS_TABLE, STYLES_TABLE, ALBUMS_TABLE, DISCS_TABLE, TRACKS_TABLE]
  #Attributes: link to database and array of hashes of track records.
  attr_reader :db, :items
  #Methods.
  #Initializes attributes and create tables if they not exist.
  def initialize(db, items)
    @db, @items = db, items
    TABLES.each do |table|
      sql = "CREATE TABLE IF NOT EXISTS #{table.header} ("
      table.columns.each {|column| sql += "#{column.header} #{column.tycon}, "}
      sql = table.constraint.nil? ? "#{sql.slice(0, sql.length - 2)})" : "#{sql}#{table.constraint})"
      @db.execute(sql)
    end
  end
  #Safely quotes string to SQLite3. If nil returns NULL.
  def quote(string)
    result = string.nil? ? NULL : "'#{SQLite3::Database.quote(string)}'"
  end
  #Inserts raw into table if not exists and returns id. If exists returns id of existing one.
  #Could have 3 o4 4 arguments. The last 3 - arrays or single items.
  def insert_if_not_exists(table, check_columns, check_items, insert_items = check_items)
    #Converts arguments to arrays if they are not.
    check_columns = [check_columns] if check_columns.class != Array
    check_items = [check_items] if check_items.class != Array
    insert_items = [insert_items] if insert_items.class != Array
    #If no items to add returns nil (quoted to NULL).
    return nil if insert_items.first.nil?
    #Checks if row presents in table. If it's true returns id of row.
    sql = "SELECT id FROM #{table.header} WHERE "
    check_columns.each_with_index {|check_column, i| sql += "#{check_column.header} = #{quote(check_items[i])} AND "}
    sql = sql.slice(0, sql.length - 5)
    result = @db.execute(sql).first
    #If false inserts row into table and returns id of new row.
    if result.nil?
      sql = "INSERT INTO #{table.header} VALUES (#{NULL}, "
      insert_items.each {|insert_item| sql += "#{quote(insert_item)}, "}
      sql = "#{sql.slice(0, sql.length - 2)})"
      @db.execute(sql)
      result = @db.last_insert_row_id
    else result = result.first
    end
    result.to_s
  end
  #For every track records item inserts records into corresponding tables.
  def insert_records
    @items.each do |item|
      #Artists, publishers, codecs and styles tables.
      album_artist_id = insert_if_not_exists(ARTISTS_TABLE, ARTIST_NAME_COLUMN, item[:album_artist_name])
      track_artist_id = item[:track_artist_name] == item[:album_artist_name] ?
        album_artist_id :
        insert_if_not_exists(ARTISTS_TABLE, ARTIST_NAME_COLUMN, item[:track_artist_name])
      publisher_id = insert_if_not_exists(PUBLISHERS_TABLE, PUBLISHER_COLUMN, item[:publisher])
      codec_id = insert_if_not_exists(CODECS_TABLE, CODEC_COLUMN, item[:codec])
      styles = item[:style].split(", ")
      style_1_id = insert_if_not_exists(STYLES_TABLE, STYLE_COLUMN, styles[0])
      style_2_id = insert_if_not_exists(STYLES_TABLE, STYLE_COLUMN, styles[1])
      style_3_id = insert_if_not_exists(STYLES_TABLE, STYLE_COLUMN, styles[2])
      style_4_id = insert_if_not_exists(STYLES_TABLE, STYLE_COLUMN, styles[3])
      style_5_id = insert_if_not_exists(STYLES_TABLE, STYLE_COLUMN, styles[4])
      #Albums table.
      check_columns = [ALBUM_ARTIST_ID_COLUMN, ALBUM_TITLE_COLUMN]
      check_items = [album_artist_id, item[:album_title]]
      insert_items = [album_artist_id, item[:album_title], item[:year], publisher_id, codec_id,
        style_1_id, style_2_id, style_3_id, style_4_id, style_5_id, item[:comment]]
      album_id = insert_if_not_exists(ALBUMS_TABLE, check_columns, check_items, insert_items)
      #Discs table.
      check_columns = [DISC_NUMBER_COLUMN, ALBUM_ID_COLUMN]
      check_items = [item[:disc_number], album_id]
      insert_items = [item[:disc_number], item[:disc_title], album_id]
      disc_id = insert_if_not_exists(DISCS_TABLE, check_columns, check_items, insert_items)
      #Tracks table.
      check_columns = [TRACK_NUMBER_COLUMN, DISC_ID_COLUMN]
      check_items = [item[:track_number], disc_id]
      insert_items = [item[:track_number], track_artist_id, item[:track_title], disc_id]
      track_id = insert_if_not_exists(TRACKS_TABLE, check_columns, check_items, insert_items)
      #puts "Album: #{album_id}\tDisc: #{disc_id}\tTrack: #{track_id}"
    end
  end
end
#Creates object In_out & initializes it with command line arguments.
in_out = InOut.new(ARGV[0], ARGV[1], ARGV[2])
#Main cycle. For each input file gets lines from file, parses them (Info class),
#stores in tree of arrays (Album class), defaults empty records,
#converts to array of track records & add it to output items array.
in_out.get_each {|lines| Album.new(Info.new(lines)).default.to_items}
#Puts track records for all albums to output file of selected kind.
in_out.put