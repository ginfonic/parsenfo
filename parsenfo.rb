#!/usr/bin/ruby -w
#: Title		: parsenfo (Parse NFO)
#: Date			: 2010-06-10
#: Author		: "Eugene Fokin" <ginfonic@gmail.com>
#: Version		: 2.0
#: Description	: Parses text file with tagged CD record info
#: Description	: into records ready to be stored in SQL database.
#: Arguments	: [output_file_kind] input_file/input_folder [output_file]

#In_out class for parsing arguments, getting & puting strings from/to text file.
class In_out
  attr_reader :out_file_kind, :in_files, :out_file
  #Initializes class with kind of output file, input & output files.
  def initialize(out_file_kind, in_file, out_file)
    #Defines kind of output file: CSV, tab delimited or MySQL (dummy).
    case out_file_kind
    when "-c"
      @out_file_kind = :csv
      out_file_ext = ".csv"
    when "-t"
      @out_file_kind = :tab
      out_file_ext = ".txt"
    when "-m"
      @out_file_kind = :mysql
      out_file_ext = ".sql"
    else
      @out_file_kind = :csv
      out_file_ext = ".csv"
      out_file = in_file
      in_file = out_file_kind
    end
    #Defines input files.
    #Extention of input files.
    in_file_ext = ".txt"
    #Array of input files.
    @in_files = []
    if in_file.nil?
    #If in_file is folder gets all files from it.
    elsif File.directory?(in_file)
      @in_files = Dir["#{in_file}/*#{in_file_ext}"]
    #If in_file is file, exists and of right kind add it to array.
    elsif File.exist?(in_file) && File.extname(in_file) == in_file_ext
      @in_files << in_file
    end
    #Exits with message if no input files.
    if @in_files.empty?
      puts "Please, select an input text file!"
      exit
    end
    #Defines output file.
    #If out_file is not selected defaults it.
    if out_file.nil?
      @out_file = "#{File.dirname(@in_files[0])}/parsenfo#{out_file_ext}"
    #If out_file have no full path store it in folder with first in_file.
    elsif File.dirname(out_file) == "."
      @out_file = "#{File.dirname(@in_files[0])}/#{out_file}"
    else
      @out_file = out_file
    end
  end
  #Gets strings from each input file to array and raises external block to treat it.
  def get_each
    @in_files.each do |in_file|
      lines = []
      File.foreach(in_file) {|line| lines << line.chomp}
      yield lines
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
  #Puts array of track records to output file.
  def put(items)
    lines = if @out_file_kind == :tab then to_tab_lines(items)
    else to_csv_lines(items) end
    File.open(@out_file, "a") {|fp| fp.puts lines}
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
Disc = Struct.new(:disc_number, :disc_title, :tracks)
Track = Struct.new(:track_number, :track_artist_name, :track_title, :composer)
class Album
  attr_reader :codec, :album_artist_name, :album_title, :year, :publisher, :genre, :style, :comment, :discs
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
  #Fills empty fields (disc_title, track_artist_name & composer) by default.
  def default
    @discs.each do |disc|
      if disc.disc_title.nil?
        disc.disc_title = @discs.length > 1 ? @album_title + " CD" + disc.disc_number : @album_title
      end
      disc.tracks.each do |track|
        track.track_artist_name = @album_artist_name if track.track_artist_name.nil?
        if track.composer.nil?
          if !@discs[0].tracks[0].composer.nil? then track.composer = @discs[0].tracks[0].composer
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
        item = [@codec, @album_artist_name, @album_title, @year, @publisher, @genre, @style, @comment]
        item += [disc.disc_number, disc.disc_title]
        item += [track.track_number, track.track_artist_name, track.track_title, track.composer]
        items << item
      end
    end
    items
  end
end
#Creates object In_out & initializes it with command line arguments.
in_out = In_out.new(ARGV[0], ARGV[1], ARGV[2])
#Array for storing track records of all albums.
out_items = []
#Main cycle. For each input file gets lines from file, parses them (Info class),
#stores in tree of arrays (Album class), defaults empty fields,
#converts to array of track records & add it to out_items array.
in_out.get_each {|lines| out_items += Album.new(Info.new(lines)).default.to_items}
#Puts track records for all albums to output file of selected kind.
in_out.put(out_items)