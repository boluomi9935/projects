USE `probe`;

-- ALTER TABLE `probe`.`complete` ADD INDEX `sequenceLig`;
-- ALTER TABLE `probe`.`complete` ADD INDEX `sequenceM13`;
-- ALTER TABLE `probe`.`complete` ADD INDEX `sequence`;
-- ALTER TABLE `probe`.`complete` ADD INDEX `ligant`;

ALTER TABLE `probe`.`complete` ADD INDEX (`sequenceLig`), ADD INDEX (`sequenceM13`), ADD INDEX (`sequence`), ADD INDEX (`ligant`), ADD INDEX (`idOrganism`);

-- CREATE INDEX `LIG`    ON `probe`.`complete` (`sequenceLig` ASC) ;
-- CREATE INDEX `M13`    ON `probe`.`complete` (`sequenceM13` ASC) ;
-- CREATE INDEX `SEQ`    ON `probe`.`complete` (`sequence`    ASC) ;
-- CREATE INDEX `LIGANT` ON `probe`.`complete` (`ligant`      ASC) ;
