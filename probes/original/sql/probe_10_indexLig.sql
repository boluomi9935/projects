DROP TABLE IF EXISTS `probe`.`uniq_lig`;
CREATE TABLE `probe`.`uniq_lig` (PRIMARY KEY (idCoordinates)) ENGINE InnoDB ROW_FORMAT = DYNAMIC (SELECT idCoordinates, sequenceLig FROM probe.complete GROUP BY ligant HAVING COUNT(sequenceLig) = 1);


