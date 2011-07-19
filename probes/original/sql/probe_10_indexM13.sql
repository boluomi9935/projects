DROP TABLE IF EXISTS `probe`.`uniq_m13`;
CREATE TABLE `probe`.`uniq_m13` (PRIMARY KEY (idCoordinates)) ENGINE InnoDB (SELECT idCoordinates, sequenceM13 FROM probe.complete GROUP BY ligant HAVING COUNT(sequenceM13) = 1);
