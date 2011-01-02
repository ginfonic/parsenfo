SELECT artists.artist_name AS album_artist_name, 
	albums.year, 
	albums.album_title, 
	publishers.publisher, 
	codecs.codec, 
	styles_1.style style_1, 
	styles_2.style style_2, 
	styles_3.style style_3, 
	styles_4.style style_4, 
	styles_5.style style_5, 
	albums.comment
FROM albums
	JOIN artists ON albums.album_artist_id = artists.id
	JOIN publishers ON albums.publisher_id = publishers.id
	JOIN codecs ON albums.codec_id = codecs.id
	LEFT JOIN styles styles_1 ON albums.style_1_id = styles_1.id
	LEFT JOIN styles styles_2 ON albums.style_2_id = styles_2.id
	LEFT JOIN styles styles_3 ON albums.style_3_id = styles_3.id
	LEFT JOIN styles styles_4 ON albums.style_4_id = styles_4.id
	LEFT JOIN styles styles_5 ON albums.style_5_id = styles_5.id
ORDER BY album_artist_name ASC, albums.year ASC, albums.album_title ASC