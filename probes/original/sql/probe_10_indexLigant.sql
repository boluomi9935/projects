DROP TABLE IF EXISTS `probe`.`uniq_ligant`;
CREATE TABLE `probe`.`uniq_ligant` (PRIMARY KEY (idCoordinates)) ENGINE InnoDB (SELECT idCoordinates, ligant      FROM probe.complete GROUP BY ligant HAVING COUNT(ligant)      = 1);

