USE taxonomy;
CREATE TABLE taxonomy (INDEX(taxon_id), INDEX(ncbi_taxon_id), INDEX (name), INDEX (name_class), INDEX (left_value), INDEX (right_value)) ENGINE=INNODB SELECT taxon.*, taxon_name.name, taxon_name.name_class FROM taxon, taxon_name WHERE taxon_name.taxon_id = taxon.taxon_id;
DROP TAXON;
DROP TAXON_NAME;
