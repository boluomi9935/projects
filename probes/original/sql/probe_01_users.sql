GRANT ALL PRIVILEGES ON *.* TO 'saulo'@'localhost' IDENTIFIED BY 'cbscbs12' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'saulo'@'%'         IDENTIFIED BY 'cbscbs12' WITH GRANT OPTION;

GRANT RELOAD, PROCESS ON *.* TO 'admin'@'localhost';

GRANT USAGE ON probe.* TO 'dummy'@'localhost';
GRANT USAGE ON probe.* TO 'probe'@'localhost';

GRANT ALL PRIVILEGES ON probe.* TO 'probe'@'localhost';

