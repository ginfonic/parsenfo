SELECT album_artists.artist_name AS album_artist_name, 
	albums.year, 
	albums.album_title, 
	discs.disc_number, 
	tracks.track_number, 
	track_artists.artist_name AS track_artist_name, 
	tracks.track_title
FROM tracks
	JOIN artists track_artists ON tracks.track_artist_id = track_artists.id
	JOIN discs ON tracks.disc_id = discs.id
	JOIN albums ON discs.album_id = albums.id
	JOIN artists album_artists ON albums.album_artist_id = album_artists.id
ORDER BY album_artist_name ASC, albums.year ASC, albums.album_title ASC, discs.disc_number ASC, tracks.track_number ASC