SELECT DISTINCT artists.artist_name AS album_artist_name, 
	albums.album_title
FROM albums, artists, styles
WHERE albums.album_artist_id = artists.id
AND ((albums.style_1_id = styles.id
		AND styles.style LIKE '%Prog%')
	OR (albums.style_2_id = styles.id
		AND styles.style LIKE '%Prog%')
	OR (albums.style_3_id = styles.id
		AND styles.style LIKE '%Prog%')
	OR (albums.style_3_id = styles.id
		AND styles.style LIKE '%Prog%')
	OR (albums.style_4_id = styles.id
		AND styles.style LIKE '%Prog%')
	OR (albums.style_5_id = styles.id
		AND styles.style LIKE '%Prog%'))
AND albums.year > 2000
ORDER BY album_artist_name ASC, albums.album_title ASC