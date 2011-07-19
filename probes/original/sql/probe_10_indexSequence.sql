DROP TABLE IF EXISTS `probe`.`uniq_sequence`;
CREATE TABLE `probe`.`uniq_sequence` (PRIMARY KEY (idCoordinates)) ENGINE InnoDB (SELECT idCoordinates, sequence    FROM probe.complete GROUP BY ligant HAVING COUNT(sequence)    = 1);


