#ADD USERS
#echo "SQL: ADDING SQL USERS"
mysql -uroot -pcbscbs12 < /home/saulo/Desktop/rolf/sql/probe_01_users.sql

#CREATE DATABASE
#echo "SQL: CREATING SQL DATABASE AND STRUCTURE"
mysql -uprobe < /home/saulo/Desktop/rolf/sql/probe_02_create.sql

#ADD DEFAULT VALUES
#echo "SQL: ADDING DEFAULT VALUES"
mysql -uprobe < /home/saulo/Desktop/rolf/sql/probe_04_ADD.sql

