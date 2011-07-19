#!/bin/sh
mysql -u root --password=cbscbs12 < setup.sql
mysql -u root --password=cbscbs12 < create.sql

#./phyinit.pl --dbuser=probe --driver=mysql --dbname=taxonomy --host=localhost

./load_ncbi_taxonomy.pl --dbname taxonomy --driver mysql --host localhost --dbuser probe --verbose=2 --download


mysql -u root --password=cbscbs12 < crate_table.sql