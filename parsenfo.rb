#!/usr/bin/ruby -w
#: Title		: pafsenfo (Parse NFO)
#: Date			: 2010-06-07
#: Author		: "Eugene Fokin" <ginfonic@gmail.com>
#: Version		: 1.0
#: Description	: Parses text file with tagged CD record info
#: Description	: into records ready to be stored in SQL database.
#: Arguments	: input_file/input_folder
#1. Reads input file name from arguments.
if !ARGV.empty?
  in_file = ARGV[0]
  if ARGV[1].nil?
    dot_i = in_file.rindex('.')
    out_file = in_file.slice(0, dot_i) + '-tab' + in_file.slice(dot_i, in_file.length - dot_i)
  else
    out_file = ARGV[1]
  end
else
  puts "Please, select an input and output text files!"
  exit
end
#2. Reads input file strings to array.
lines = []
File.foreach(in_file) {|line| lines << line.chomp}
#puts lines
#3. Fills temporary array with data from input array.
Info = Struct.new(:codec, :album_artist_name, :album_title, :year, :publisher, :genre, :style, :comment,
  :track_counts, :disc_titles, :track_artist_names, :track_titles, :composers)
info = Info.new(nil, nil, nil, nil, nil, nil, nil, nil, [], [], [], [], [])
for line in lines
  next if line.empty?
  tag = line.slice!(0, line.index("=") + 1)
  case tag.slice(0, 3)
  when "COD"
    info.codec = line
  when "ART"
    info.album_artist_name = line
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
    info.track_artist_names << line
  when "TRA"
    info.track_titles << line
  when "CMP"
    info.composers << line
  end
end
#puts info
#4. Fills tree of arrays with data from temporary array.
Album = Struct.new(:codec, :album_artist_name, :album_title, :year, :publisher, :genre, :style, :comment, :discs)
Disc = Struct.new(:disc_number, :disc_title, :tracks)
Track = Struct.new(:track_number, :track_artist_name, :track_title, :composer)
album = Album.new(info.codec, info.album_artist_name, info.album_title, info.year,
  info.publisher, info.genre, info.style, info.comment, [])
disc_count = info.track_counts.length + 1
i = j = 0
while disc_count > i
  disc = Disc.new((i + 1).to_s, info.disc_titles[i], [])
  track_count = info.track_counts[i].nil? ?
    info.track_titles.length - info.track_counts.inject {|sum, n| sum.to_i + n.to_i}.to_i :
    info.track_counts[i].to_i
  k = 0
  while track_count > k
    track = Track.new((k + 1).to_s, info.track_artist_names[j], info.track_titles[j], info.composers[j])
    disc.tracks << track
    j += 1
    k += 1
  end
  album.discs << disc
  i += 1
end
#puts album
#6. Fills empty fields by default.
for disc in album.discs
  disc.disc_title = album.album_title + " CD" + disc.disc_number.to_i if disc.disc_title.nil?
  for track in disc.tracks
    track.track_artist_name = album.album_artist_name if track.track_artist_name.nil?
    if track.composer.nil?
      if !album.discs[0].tracks[0].composer.nil? then track.composer = album.discs[0].tracks[0].composer
      else track.composer = track.track_artist_name end
    end
  end
end
#7. Converts tree of arrays to array of tab delimited track records.
lines = []
lines << "codec\talbum_artist_name\talbum_title\tyear\tpublisher\tgenre\tstyle\tcomment\tdisc_number\tdisc_title\ttrack_number\ttrack_artist_name\ttrack_title\tcomposer"
for disc in album.discs
  for track in disc.tracks
    line = "#{album.codec}\t#{album.album_artist_name}\t#{album.album_title}\t#{album.year}\t"
    line += "#{album.publisher}\t#{album.genre}\t#{album.style}\t#{album.comment}\t"
    line += "#{disc.disc_number}\t#{disc.disc_title}\t"
    line += "#{track.track_number}\t#{track.track_artist_name}\t#{track.track_title}\t#{track.composer}"
    lines << line
    puts line
  end
end
#8. Writes strings from array to output file.
File.open(out_file, 'w') {|fp| fp.puts lines}