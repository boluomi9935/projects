SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS `probe` ;
USE `probe`;

-- -----------------------------------------------------
-- Table `probe`.`organism`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`organism` ;

CREATE  TABLE IF NOT EXISTS `probe`.`organism` (
  `idorganism` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `nameOrganism` VARCHAR(255) NOT NULL ,
  `count` MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
  PRIMARY KEY (`idorganism`) )
ENGINE = InnoDB
AVG_ROW_LENGTH = 50;

CREATE UNIQUE INDEX `organism_unique` ON `probe`.`organism` (`nameOrganism` ASC) ;


-- -----------------------------------------------------
-- Table `probe`.`probe`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`probe` ;

CREATE  TABLE IF NOT EXISTS `probe`.`probe` (
  `idprobe` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `sequence` VARCHAR(255) NOT NULL ,
  `probeGc` TINYINT UNSIGNED NOT NULL ,
  `probeTm` TINYINT UNSIGNED NOT NULL ,
  `count` MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
  PRIMARY KEY (`idprobe`) )
ENGINE = InnoDB
PACK_KEYS = DEFAULT;

CREATE UNIQUE INDEX `sequence_unique` ON `probe`.`probe` (`sequence` ASC) ;


-- -----------------------------------------------------
-- Table `probe`.`coordinates`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`coordinates` ;

CREATE  TABLE IF NOT EXISTS `probe`.`coordinates` (
  `idCoordinates` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `idOrganism` INT UNSIGNED NOT NULL ,
  `idProbe` INT UNSIGNED NOT NULL ,
  `startLig` INT UNSIGNED NOT NULL ,
  `startM13` INT UNSIGNED NOT NULL ,
  `endM13` INT UNSIGNED NOT NULL ,
  `chromossome` MEDIUMINT UNSIGNED NOT NULL ,
  `count` MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
  PRIMARY KEY (`idCoordinates`, `idOrganism`, `idProbe`) ,
  CONSTRAINT `fk_coordinates_organism`
    FOREIGN KEY (`idOrganism` )
    REFERENCES `probe`.`organism` (`idorganism` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_coordinates_probe`
    FOREIGN KEY (`idProbe` )
    REFERENCES `probe`.`probe` (`idprobe` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

CREATE UNIQUE INDEX `coordinates_uniqueness` ON `probe`.`coordinates` (`idOrganism` ASC, `chromossome` ASC, `idProbe` ASC, `startLig` ASC, `endM13` ASC) ;

CREATE INDEX `fk_coordinates_organism` ON `probe`.`coordinates` (`idOrganism` ASC) ;

CREATE INDEX `fk_coordinates_probe` ON `probe`.`coordinates` (`idProbe` ASC) ;


-- -----------------------------------------------------
-- Placeholder table for view `probe`.`original`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`original` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`countUnique`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`countUnique` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`probeUniqId`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`probeUniqId` (`id` INT);

-- -----------------------------------------------------
-- View `probe`.`original`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`original` ;
DROP TABLE IF EXISTS `probe`.`original`;
CREATE  OR REPLACE VIEW `probe`.`original` AS 
SELECT idCoordinates, organism.nameOrganism, round((organism.count/2),0) as organismCount, startLig, startM13, endM13, chromossome, probe.count AS probeCount, sequence 
FROM coordinates,probe,organism 
WHERE (coordinates.idProbe=probe.idprobe AND coordinates.idOrganism=organism.idorganism);

-- -----------------------------------------------------
-- View `probe`.`countUnique`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`countUnique` ;
DROP TABLE IF EXISTS `probe`.`countUnique`;
CREATE  OR REPLACE VIEW `probe`.`countUnique` AS
select count(*) as countUnique from probe WHERE count = 1;

-- -----------------------------------------------------
-- View `probe`.`probeUniqId`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`probeUniqId` ;
DROP TABLE IF EXISTS `probe`.`probeUniqId`;
CREATE  OR REPLACE VIEW `probe`.`probeUniqId` AS
select idprobe from probe WHERE count = 1;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
