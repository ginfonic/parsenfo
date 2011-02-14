#!/usr/bin/ruby -w
#: Title		: parsenfo.rb (Parse NFO)
#: Date			: 2010-06-26
#: Author		: "Eugene Fokin" <ginfonic@gmail.com>
#: Version		: 3.2
#: Description	: Parses text file with tagged CD records info
#: Description	: into CSV or tab delimited text file or to SQLite3 database.
#: Arguments	: [-options] input_file|input_folder [output_file]
#
require "rubygems"
require "sqlite3"

#InOut class for parsing arguments, getting strings from text file, storing track records of all albums
#& putting them to CSV or tab delimited text file or to SQLite3 database.
class InOut
	#Constants.
	IN_FILE_EXT = ".txt"
	OUT_LOG_FILE_NAME = "parsenfo"
	LOG_FILE_EXT = ".log"
	INFO = %q{
parsenfo.rb # version: 3.2 # date: 2010-06-26
created by: eugene fokin <ginfonic@gmail.com>
description: parses text file with tagged cd records info
	into csv or tab delimited text file or to sqlite3 database

usage: parsenfo.rb [-options] input_file|input_folder [output_file]

options: -fvctl
	f: creates log file parsenfo.log in script folder (default)
	v: verbose mode, puts log to console
		also by default log adds to file parcenfo.log in script folder
	c: output file kind -- csv, extention -- .csv (default)
	t: output file kind -- tab delimited text, extention -- .txt
	l: output file kind -- sqlite3 database, extention -- .db
input_file: nfo text file with tagged cd records info
input_folder: folder with these files:
	.txt extention, no recursing
output_file: file for storing parsed cd records info:
	by default has name parsenfo,
	extention corresponded to selected kind of output file
	and stored into folder with input_file

Please, select input file or folder!}
	#Attributes.
	#attr_reader :log_kind, :out_file_kind, :log_file, :in_files, :out_file, :log_lines, :out_items

	#Public methods.
	#Initializes class with kind of log & output file, input & output files.
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
		@in_files = []
		if in_file.nil?
		#If in_file is folder gets all files from it.
		elsif File.directory?(in_file)
			@in_files = Dir["#{in_file}/*#{IN_FILE_EXT}"]
		#If in_file is file, exists and of right kind add it to array.
		elsif File.exist?(in_file) && File.extname(in_file) == IN_FILE_EXT
			@in_files << in_file
		end
		#Exits with help message if no valid input files.
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
				@out_items += album_items
				@log_lines << to_log(album_items) 
			end
		end
	end

	#Puts array of track records to output file.
	def put
		if @out_file_kind == :sqlite3
			RecordsDatabase.open(@out_file) {|db| db.insert_records(to_hashes(@out_items))}
		else
			lines = if @out_file_kind == :tab then to_tab_lines(@out_items)
			else to_csv_lines(@out_items) end
			File.open(@out_file, "a") {|fp| fp.puts lines}
		end
		#Puts log lines to log file.
		File.open(@log_file, "a") {|fp| fp.puts @log_lines}
	end

	#Private methods.
	private
	
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
			hashes << {:codec => item[0], :album_artist => item[1], :album_title => item[2], :year => item[3],
				:publisher => item[4], :genre => item[5], :style => item[6], :comment => item[7], :cover => item[8],
				:disc_number => item[9], :disc_title => item[10], :track_number => item[11],
				:track_artist => item[12], :track_title => item[13], :composer => item[14]}
		end
		hashes
	end

	def to_log(items)
		log_line = "#{@log_lines.length}: #{items[0][1]} - #{items[0][2]}"
		puts log_line if @log_kind == :verbose
		log_line
	end
end

#Album class with tree of arrays (Disc, Track structures) for storing data from input array.
class Album
	#Types.
	Info = Struct.new(:codec, :album_artist, :album_title, :year, :publisher, :genre, :style, :comment,
		:track_counts, :disc_titles, :track_artists, :track_titles, :composers)
	Disc = Struct.new(:disc_number, :disc_title, :tracks)
	Track = Struct.new(:track_number, :track_artist, :track_title, :composer)

	#Attributes.
	#attr_reader :codec, :album_artist, :album_title, :year, :publisher, :genre, :style, :comment, :cover, :discs

	#Methods.
	#Fills tree of arrays with data from input array.
	def initialize(lines)
		#Parses data from input array and returns them in Info structure.
		info = parse_info(lines)
		@codec, @album_artist, @album_title, @year, @publisher, @genre, @style, @comment, @cover, @discs =
			info.codec, info.album_artist, info.album_title, info.year,
			info.publisher, info.genre, info.style, info.comment, nil, []
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
				track = Track.new((k + 1).to_s, info.track_artists[j], info.track_titles[j], info.composers[j])
				disc.tracks << track
				j += 1
				k += 1
			end
			#Adds new disc.
			@discs << disc
			i += 1
		end
		#Fills empty records by default.
		default
	end

	#Converts tree of arrays to array of track records.
	def to_items
		items = []
		@discs.each do |disc|
			disc.tracks.each do |track|
				items << [@codec, @album_artist, @album_title, @year, @publisher, @genre, @style, @comment, @cover,
					disc.disc_number, disc.disc_title, track.track_number, track.track_artist, track.track_title, track.composer]
			end
		end
		items
	end

	#Private methods.
	private

	#Parses data from input array.
	def parse_info(lines)
		#Creates structure info for storing parsed data.
		info = Info.new(nil, nil, nil, nil, nil, nil, nil, nil, [], [], [], [], [])
		lines.each do |line|
			#Finds tag name in line, rejects empty lines & lines with no tag name.
			next if line.empty? || (tag_end = line.index("=")).nil? || tag_end > 5
			#Detaches tag name.
			tag = line.slice!(0, tag_end + 1)
			#Fills values based on tag names.
			case tag.slice(0, 3)
			when "COD"
				info.codec = line
			when "ART"
				info.album_artist = line
			when "ALB"
				info.album_title = line
			when "YEA"
				info.year = line
			when "PUB"
				info.publisher = line
			when "GEN"
				info.genre = line
			when "STY"
				info.style = line
			when "CMT"
				info.comment = line
			when "MTC"
				info.track_counts << line
			when "MAL"
				info.disc_titles << line
			when "TAR"
				info.track_artists << line
			when "TRA"
				info.track_titles << line
			when "CMP"
				info.composers << line
			end
		end
		#Returns info.
		info
	end

	#Fills empty records (disc_title, track_artist & composer) by default.
	def default
		@discs.each do |disc|
			if disc.disc_title.nil?
				disc.disc_title = @discs.length > 1 ? "#{@album_title} CD#{disc.disc_number}" : @album_title
			end
			disc.tracks.each do |track|
				track.track_artist = @album_artist if track.track_artist.nil?
				if track.composer.nil?
					if !@discs.first.tracks.first.composer.nil? then track.composer = @discs.first.tracks.first.composer
					else track.composer = track.track_artist end
				end
			end
		end
		self
	end
end

#Redefines SQLite3::Database class.
class SQLite3Database < SQLite3::Database
	#Constants.
	NULL = "NULL"

	#Class methods.
	class << self
		#Opens database from file, calls block & closes database.
		def open(file)
			db = new(file)
			yield db
			db.close
		end

		#Safely quotes string to SQLite3. If nil returns NULL.
		def quote(string)
			string.nil? ? NULL : "'#{super(string)}'"
		end
	end
end

#Creates and operates SQLite3 database to store records.
class RecordsDatabase < SQLite3Database
	#Types.
	Column = Struct.new(:header, :type_constraint)
	Table = Struct.new(:header, :constraint, :columns)

	#Column definitions.

	#TITLES_TABLE, YEARS_TABLE, PUBLISHERS_TABLE, CODECS_TABLE, COMMENTS_TABLE,
	#COVERS_TABLE, ARTISTS_TABLE, STYLES_TABLE, COMPOSERS_TABLE.
	TITLE_COLUMN = Column.new("title", "TEXT NOT NULL UNIQUE COLLATE NOCASE")
	YEAR_COLUMN = Column.new("year",
		"INTEGER NOT NULL CHECK ((year > 1900) AND (year < SUBSTR(CURRENT_DATE,1,4) + 1)) UNIQUE")
	PUBLISHER_COLUMN = Column.new("publisher", "TEXT NOT NULL UNIQUE COLLATE NOCASE")
	CODEC_COLUMN = Column.new("codec", "TEXT NOT NULL UNIQUE COLLATE NOCASE")
	COMMENT_COLUMN = Column.new("comment", "TEXT NOT NULL UNIQUE COLLATE NOCASE")  
	COVER_COLUMN = Column.new("cover", "BLOB NOT NULL UNIQUE")
	ARTIST_COLUMN = Column.new("artist", "TEXT NOT NULL UNIQUE COLLATE NOCASE")
	STYLE_COLUMN = Column.new("style", "TEXT NOT NULL UNIQUE COLLATE NOCASE")
	COMPOSER_COLUMN = Column.new("composer", "TEXT NOT NULL UNIQUE COLLATE NOCASE")

	#ALBUMS_TABLE.
	TITLE_ID_COLUMN = Column.new("title_id", "INTEGER NOT NULL")
	YEAR_ID_COLUMN = Column.new("year_id", "INTEGER NOT NULL")
	PUBLISHER_ID_COLUMN = Column.new("publisher_id", "INTEGER NOT NULL")
	CODEC_ID_COLUMN = Column.new("codec_id", "INTEGER NOT NULL")
	COMMENT_ID_COLUMN = Column.new("comment_id", "INTEGER")
	COVER_ID_COLUMN = Column.new("cover_id", "INTEGER")

	#TRACKS_TABLE.
	ALBUM_ID_COLUMN = Column.new("album_id", "INTEGER NOT NULL")
	DISC_NUMBER_COLUMN = Column.new("disc_number", "INTEGER NOT NULL CHECK (disc_number > 0)")
	TRACK_NUMBER_COLUMN = Column.new("track_number", "INTEGER NOT NULL CHECK (track_number > 0)")

	#ALBUMS_ARTISTS_TABLE, TRACKS_ARTISTS_TABLE.
	TRACK_ID_COLUMN = Column.new("track_id", "INTEGER NOT NULL")
	ARTIST_ID_COLUMN = Column.new("artist_id", "INTEGER NOT NULL")
	ARTIST_ORDER_COLUMN = Column.new("artist_order", "INTEGER NOT NULL")

	#ALBUMS_STYLES_TABLE.
	STYLE_ID_COLUMN = Column.new("style_id", "INTEGER NOT NULL")
	STYLE_ORDER_COLUMN = Column.new("style_order", "INTEGER NOT NULL")

	#TRACKS_COMPOSERS_TABLE.
	COMPOSER_ID_COLUMN = Column.new("composer_id", "INTEGER NOT NULL")
	COMPOSER_ORDER_COLUMN = Column.new("composer_order", "INTEGER NOT NULL")

	#Table definitions.
	#Parent tables.
	TITLES_TABLE = Table.new("titles", nil, [TITLE_COLUMN])
	YEARS_TABLE = Table.new("years", nil, [YEAR_COLUMN])
	PUBLISHERS_TABLE = Table.new("publishers", nil, [PUBLISHER_COLUMN])
	CODECS_TABLE = Table.new("codecs", nil, [CODEC_COLUMN])
	COMMENTS_TABLE = Table.new("comments", nil, [COMMENT_COLUMN])
	COVERS_TABLE = Table.new("covers", nil, [COVER_COLUMN])
	STYLES_TABLE = Table.new("styles", nil, [STYLE_COLUMN])
	COMPOSERS_TABLE = Table.new("composers", nil, [COMPOSER_COLUMN])
	ARTISTS_TABLE = Table.new("artists", nil, [ARTIST_COLUMN])

	#Child tables.
	ALBUMS_TABLE = Table.new("albums", nil,
		[TITLE_ID_COLUMN, YEAR_ID_COLUMN, PUBLISHER_ID_COLUMN, CODEC_ID_COLUMN, COMMENT_ID_COLUMN, COVER_ID_COLUMN])
	TRACKS_TABLE = Table.new("tracks",
		"UNIQUE (#{TRACK_NUMBER_COLUMN.header}, #{DISC_NUMBER_COLUMN.header}, #{ALBUM_ID_COLUMN.header})",
		[TITLE_ID_COLUMN, TRACK_NUMBER_COLUMN, DISC_NUMBER_COLUMN, ALBUM_ID_COLUMN])

	#Junction tables.
	ALBUMS_ARTISTS_TABLE = Table.new("albums_artists", "UNIQUE (#{ALBUM_ID_COLUMN.header}, #{ARTIST_ID_COLUMN.header})",
		[ALBUM_ID_COLUMN, ARTIST_ID_COLUMN, ARTIST_ORDER_COLUMN])
	ALBUMS_STYLES_TABLE = Table.new("albums_styles", "UNIQUE (#{ALBUM_ID_COLUMN.header}, #{STYLE_ID_COLUMN.header})",
		[ALBUM_ID_COLUMN, STYLE_ID_COLUMN, STYLE_ORDER_COLUMN])
	TRACKS_ARTISTS_TABLE = Table.new("tracks_artists", "UNIQUE (#{TRACK_ID_COLUMN.header}, #{ARTIST_ID_COLUMN.header})",
		[TRACK_ID_COLUMN, ARTIST_ID_COLUMN, ARTIST_ORDER_COLUMN])
	TRACKS_COMPOSERS_TABLE = Table.new("tracks_composers", "UNIQUE (#{TRACK_ID_COLUMN.header}, #{COMPOSER_ID_COLUMN.header})",
		[TRACK_ID_COLUMN, COMPOSER_ID_COLUMN, COMPOSER_ORDER_COLUMN])

	#Database definition.
	TABLES = [TITLES_TABLE, YEARS_TABLE, PUBLISHERS_TABLE, CODECS_TABLE, COMMENTS_TABLE,
		COVERS_TABLE, STYLES_TABLE, COMPOSERS_TABLE, ARTISTS_TABLE, ALBUMS_TABLE, TRACKS_TABLE,
		ALBUMS_ARTISTS_TABLE, ALBUMS_STYLES_TABLE, TRACKS_ARTISTS_TABLE, TRACKS_COMPOSERS_TABLE]

	#Methods.
	#Initializes database & creates tables if they not exist.
	def initialize(file)
		#Initializes superclass -- creates database.
		super(file)
		#Creates tables if they not exist
		TABLES.each do |table|
			sql = "CREATE TABLE IF NOT EXISTS #{table.header} ("
			table.columns.each {|column| sql += "#{column.header} #{column.type_constraint}, "}
			sql = table.constraint.nil? ? "#{sql.slice(0, sql.length - 2)})" : "#{sql}#{table.constraint})"
			self.execute(sql)
		end
	end

	#For every track records item inserts records into corresponding tables.
	def insert_records(items)
		items.each do |item|
			#Titles, years, publishers, codecs, comments & covers tables.
			album_title_id = insert_if_not_exists(TITLES_TABLE, TITLE_COLUMN, item[:album_title])
			track_title_id = insert_if_not_exists(TITLES_TABLE, TITLE_COLUMN, item[:track_title])
			year_id = insert_if_not_exists(YEARS_TABLE, YEAR_COLUMN, item[:year])
			publisher_id = insert_if_not_exists(PUBLISHERS_TABLE, PUBLISHER_COLUMN, item[:publisher])
			codec_id = insert_if_not_exists(CODECS_TABLE, CODEC_COLUMN, item[:codec])
			comment_id = insert_if_not_exists(COMMENTS_TABLE, COMMENT_COLUMN, item[:comment])
			cover_id = insert_if_not_exists(COVERS_TABLE, COVER_COLUMN, item[:cover])

			#Styles table.
			styles = item[:style].split(", ")
			style_ids = []
			styles.each do |style|
				style_ids << insert_if_not_exists(STYLES_TABLE, STYLE_COLUMN, style)
			end

			#Composers table.
			composers = item[:composer].split(", ")
			composer_ids = []
			composers.each do |composer|
				composer_ids << insert_if_not_exists(COMPOSERS_TABLE, COMPOSER_COLUMN, composer)
			end

			#Artists table.
			#Album_artist.
			album_artists = item[:album_artist].split(", ")
			album_artist_ids = []
			album_artists.each do |album_artist|
				album_artist_ids << insert_if_not_exists(ARTISTS_TABLE, ARTIST_COLUMN, album_artist)
			end

			#Track_artist.
			if item[:track_artist] == item[:album_artist]
				track_artist_ids = album_artist_ids
			else
				track_artists = item[:track_artist].split(", ")
				track_artist_ids = []
				track_artists.each do |track_artist|
					track_artist_ids << insert_if_not_exists(ARTISTS_TABLE, ARTIST_COLUMN, track_artist)
				end
			end

			#Albums table.
			check_columns = [TITLE_ID_COLUMN]
			check_items = [album_title_id]
			insert_items = [album_title_id, year_id, publisher_id, codec_id, comment_id, cover_id]
			album_id = insert_if_not_exists(ALBUMS_TABLE, check_columns, check_items, insert_items)

			#Tracks table.
			check_columns = [TRACK_NUMBER_COLUMN, DISC_NUMBER_COLUMN, ALBUM_ID_COLUMN]
			check_items = [item[:track_number], item[:disc_number], album_id]
			insert_items = [track_title_id, item[:track_number], item[:disc_number], album_id]
			track_id = insert_if_not_exists(TRACKS_TABLE, check_columns, check_items, insert_items)
			#puts "Album: #{album_id}\tDisc: #{disc_id}\tTrack: #{track_id}"

			#Albums_Artists table.
			check_columns = [ALBUM_ID_COLUMN, ARTIST_ID_COLUMN]
			album_artist_ids.each_with_index do |album_artist_id, i|
				check_items = [album_id, album_artist_id]
				insert_items = [album_id, album_artist_id, i.to_s]
				insert_if_not_exists(ALBUMS_ARTISTS_TABLE, check_columns, check_items, insert_items)
			end

			#Albums_Styles table.
			check_columns = [ALBUM_ID_COLUMN, STYLE_ID_COLUMN]
			style_ids.each_with_index do |style_id, i|
				check_items = [album_id, style_id]
				insert_items = [album_id, style_id, i.to_s]
				insert_if_not_exists(ALBUMS_STYLES_TABLE, check_columns, check_items, insert_items)
			end

			#Tracks_Artists table.
			check_columns = [TRACK_ID_COLUMN, ARTIST_ID_COLUMN]
			track_artist_ids.each_with_index do |track_artist_id, i|
				check_items = [track_id, track_artist_id]
				insert_items = [track_id, track_artist_id, i.to_s]
				insert_if_not_exists(TRACKS_ARTISTS_TABLE, check_columns, check_items, insert_items)
			end

			#Tracks_Composers table.
			check_columns = [TRACK_ID_COLUMN, COMPOSER_ID_COLUMN]
			composer_ids.each_with_index do |composer_id, i|
				check_items = [track_id, composer_id]
				insert_items = [track_id, composer_id, i.to_s]
				insert_if_not_exists(TRACKS_COMPOSERS_TABLE, check_columns, check_items, insert_items)
			end
		end
	end

	private
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
		sql = "SELECT ROWID FROM #{table.header} WHERE "
		check_columns.each_with_index {|check_column, i| sql +=
			"#{check_column.header} = #{SQLite3Database.quote(check_items[i])} AND "}
		sql = sql.slice(0, sql.length - 5)
		result = self.execute(sql).first
		#If false inserts row into table and returns id of new row.
		if result.nil?
			sql = "INSERT INTO #{table.header} VALUES ("
			insert_items.each {|insert_item| sql += "#{SQLite3Database.quote(insert_item)}, "}
			sql = "#{sql.slice(0, sql.length - 2)})"
			self.execute(sql)
			result = self.last_insert_row_id
		else result = result.first
		end
		result.to_s
	end
end

#Creates object In_out & initializes it with command line arguments.
in_out = InOut.new(ARGV[0], ARGV[1], ARGV[2])
#Main cycle. For each input file gets lines from file,
#parses them, stores in tree of arrays, defaults empty records,
#converts to array of track records & add it to output items array.
in_out.get_each {|lines| Album.new(lines).to_items}
#Puts track records for all albums to output file of selected kind.
in_out.put