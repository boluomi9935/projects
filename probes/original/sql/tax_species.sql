SELECT terminal.taxon_id, taxon_name.*
FROM   taxon_name, taxon AS terminal
       LEFT JOIN taxon AS child
         ON (child.parent_taxon_id = terminal.taxon_id)
WHERE  child.parent_taxon_id IS NULL AND taxon_name.taxon_id = terminal.taxon_id AND taxon_name.name_class = "scientific name" order by taxon_name.name;