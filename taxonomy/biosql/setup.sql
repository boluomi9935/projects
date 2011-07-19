CREATE DATABASE IF NOT EXISTS taxonomy;
CREATE USER probe;
GRANT ALL PRIVILEGES ON taxonomy.* TO 'probe'@'localhost';


