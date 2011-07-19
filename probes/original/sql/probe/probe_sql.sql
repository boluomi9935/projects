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
  PRIMARY KEY (`idorganism`) ,
  UNIQUE INDEX `organism_unique` (`nameOrganism` ASC) )
ENGINE = InnoDB
AVG_ROW_LENGTH = 50;


-- -----------------------------------------------------
-- Table `probe`.`probe`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`probe` ;

CREATE  TABLE IF NOT EXISTS `probe`.`probe` (
  `idprobe` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `sequence` VARCHAR(255) NOT NULL ,
  PRIMARY KEY (`idprobe`) ,
  UNIQUE INDEX `sequence_unique` (`sequence` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `probe`.`coordinates`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`coordinates` ;

CREATE  TABLE IF NOT EXISTS `probe`.`coordinates` (
  `idcoordinates` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `probe_idprobe` INT UNSIGNED NOT NULL ,
  `organism_idorganism` INT UNSIGNED NOT NULL ,
  `startLig` INT UNSIGNED NOT NULL ,
  `startM13` INT UNSIGNED NOT NULL ,
  `endM13` INT UNSIGNED NOT NULL ,
  `chromossome` MEDIUMINT UNSIGNED NULL DEFAULT NULL ,
  PRIMARY KEY (`idcoordinates`, `probe_idprobe`, `organism_idorganism`) ,
  INDEX `coordinates_organism` (`organism_idorganism` ASC) ,
  INDEX `coordinates_probe` USING BTREE (`probe_idprobe` ASC) ,
  UNIQUE INDEX `coordinates_uniqueness` (`probe_idprobe` ASC, `organism_idorganism` ASC, `startLig` ASC, `startM13` ASC, `endM13` ASC, `chromossome` ASC) ,
  CONSTRAINT `Rel_03`
    FOREIGN KEY (`organism_idorganism` )
    REFERENCES `probe`.`organism` (`idorganism` )
    ON DELETE NO ACTION
    ON UPDATE RESTRICT,
  CONSTRAINT `Rel_02`
    FOREIGN KEY (`probe_idprobe` )
    REFERENCES `probe`.`probe` (`idprobe` )
    ON DELETE NO ACTION
    ON UPDATE RESTRICT)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `probe`.`fast`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`fast` ;

CREATE  TABLE IF NOT EXISTS `probe`.`fast` (
  `probe_idprobe` INT UNSIGNED NOT NULL ,
  `organism_idorganism` INT UNSIGNED NOT NULL ,
  PRIMARY KEY (`probe_idprobe`, `organism_idorganism`) ,
  INDEX `fast_FKIndex1` (`organism_idorganism` ASC) ,
  INDEX `fast_FKIndex2` (`probe_idprobe` ASC) ,
  CONSTRAINT `Rel_05`
    FOREIGN KEY (`organism_idorganism` )
    REFERENCES `probe`.`organism` (`idorganism` )
    ON DELETE NO ACTION
    ON UPDATE RESTRICT,
  CONSTRAINT `Rel_04`
    FOREIGN KEY (`probe_idprobe` )
    REFERENCES `probe`.`probe` (`idprobe` )
    ON DELETE NO ACTION
    ON UPDATE RESTRICT)
ENGINE = InnoDB;



SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
