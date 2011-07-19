SELECT taxon.taxon_id, taxon_name.* FROM taxon, taxon_name INNER JOIN taxon AS include
ON (taxon_name.taxon_id BETWEEN include.left_value AND include.right_value)
WHERE taxon_name.name = 'primates' AND taxon.taxon_id = taxon_name.taxon_id;