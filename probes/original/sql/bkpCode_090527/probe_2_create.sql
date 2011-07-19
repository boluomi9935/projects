SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS `probe` DEFAULT CHARACTER SET latin1 ;
USE `probe`;

-- -----------------------------------------------------
-- Table `probe`.`organism`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`organism` ;

CREATE  TABLE IF NOT EXISTS `probe`.`organism` (
  `idorganism` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `nameOrganism` VARCHAR(100) NOT NULL ,
  `taxonId` INT UNSIGNED NOT NULL ,
  `variant` TINYINT UNSIGNED NOT NULL ,
  `sequenceTypeId` TINYINT UNSIGNED NOT NULL ,
  `count` MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
  PRIMARY KEY (`idorganism`) ,
  UNIQUE INDEX `organism_unique` (`nameOrganism` ASC) )
ENGINE = InnoDB;


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
  `strand` CHAR(1) BINARY NOT NULL DEFAULT 'F' ,
  `chromossome` MEDIUMINT UNSIGNED NOT NULL ,
  `count` MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
  `derivated` TINYINT UNSIGNED NOT NULL DEFAULT 0 ,
  PRIMARY KEY (`idCoordinates`, `idOrganism`, `idProbe`) ,
  UNIQUE INDEX `coordinates_uniqueness` USING HASH (`idOrganism` ASC, `chromossome` ASC, `idProbe` ASC, `startLig` ASC, `endM13` ASC) )
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1
COLLATE = latin1_bin
PACK_KEYS = 1
ROW_FORMAT = COMPRESSED;


-- -----------------------------------------------------
-- Table `probe`.`probe`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`probe` ;

CREATE  TABLE IF NOT EXISTS `probe`.`probe` (
  `idprobe` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `sequenceLig` VARCHAR(15) BINARY NOT NULL ,
  `sequenceM13` VARCHAR(20) BINARY NOT NULL ,
  `probeGc` TINYINT UNSIGNED NOT NULL ,
  `probeTm` TINYINT UNSIGNED NOT NULL ,
  `count` MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
  PRIMARY KEY (`idprobe`) ,
  UNIQUE INDEX `sequence_unique` USING HASH (`sequenceLig` ASC, `sequenceM13` ASC) )
ENGINE = InnoDB
AVG_ROW_LENGTH = 40
DEFAULT CHARACTER SET = latin1
COLLATE = latin1_bin
MAX_ROWS = 60
MIN_ROWS = 20
PACK_KEYS = 1
ROW_FORMAT = COMPRESSED;


-- -----------------------------------------------------
-- Table `probe`.`chromossomes`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`chromossomes` ;

CREATE  TABLE IF NOT EXISTS `probe`.`chromossomes` (
  `idChromossome` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `idOrganism` INT UNSIGNED NOT NULL ,
  `chromossomeNumber` SMALLINT UNSIGNED NOT NULL ,
  `chromossomeShortName` VARCHAR(50) NOT NULL ,
  `chromossomeLongName` VARCHAR(120) NOT NULL ,
  PRIMARY KEY (`idChromossome`) ,
  UNIQUE INDEX `chromossomeUniqueness` USING HASH (`idOrganism` ASC, `chromossomeNumber` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `probe`.`sequenceType`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`sequenceType` ;

CREATE  TABLE IF NOT EXISTS `probe`.`sequenceType` (
  `typeId` TINYINT UNSIGNED NOT NULL ,
  `typeName` MEDIUMTEXT NOT NULL ,
  PRIMARY KEY (`typeId`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `probe`.`complete`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `probe`.`complete` ;

CREATE  TABLE IF NOT EXISTS `probe`.`complete` (
  `idCoordinates` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `idOrganism` INT UNSIGNED NOT NULL ,
  `startLig` INT UNSIGNED NOT NULL ,
  `startM13` INT UNSIGNED NOT NULL ,
  `endM13` INT UNSIGNED NOT NULL ,
  `strand` CHAR(1) BINARY NOT NULL DEFAULT 'F' ,
  `chromossome` MEDIUMINT UNSIGNED NOT NULL ,
  `derivated` TINYINT UNSIGNED NOT NULL DEFAULT 0 ,
  `sequenceLig` VARCHAR(15) BINARY NOT NULL ,
  `sequenceLigGc` TINYINT UNSIGNED NOT NULL ,
  `sequenceLigTm` TINYINT UNSIGNED NOT NULL ,
  `sequenceM13` VARCHAR(25) BINARY NOT NULL ,
  `sequenceM13Gc` TINYINT UNSIGNED NOT NULL ,
  `sequenceM13Tm` TINYINT UNSIGNED NOT NULL ,
  `sequence` VARCHAR(35) BINARY NOT NULL ,
  `sequenceGc` TINYINT UNSIGNED NOT NULL ,
  `sequenceTm` TINYINT UNSIGNED NOT NULL ,
  `ligant` CHAR(8) BINARY NOT NULL ,
  PRIMARY KEY (`idCoordinates`) ,
  INDEX `LIG` (`sequenceLig` ASC) ,
  INDEX `M13` (`sequenceM13` ASC) ,
  INDEX `SEQ` (`sequence` ASC) ,
  INDEX `LIGANT` (`ligant` ASC) )
ENGINE = InnoDB
AVG_ROW_LENGTH = 100
DEFAULT CHARACTER SET = latin1
COLLATE = latin1_bin
MAX_ROWS = 1000000000
MIN_ROWS = 3000000
PACK_KEYS = 1
ROW_FORMAT = COMPRESSED;


-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_GetTotalProbeCountUnique`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_GetTotalProbeCountUnique` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_ListUniqueProbeIds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_ListUniqueProbeIds` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_ListOrganismsUniqueProbeIdTotalUnique`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_ListOrganismsUniqueProbeIdTotalUnique` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_ListOrganismsUniqueProbeId`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_ListOrganismsUniqueProbeId` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_ListUniqueAnalisedProbes`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_ListUniqueAnalisedProbes` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_ListProbeCoreUniqueFromProbe`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_ListProbeCoreUniqueFromProbe` (`id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `probe`.`v_originalFinal`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `probe`.`v_originalFinal` (`id` INT);

-- -----------------------------------------------------
-- View `probe`.`v_GetTotalProbeCountUnique`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_GetTotalProbeCountUnique` ;
DROP TABLE IF EXISTS `probe`.`v_GetTotalProbeCountUnique`;
CREATE  OR REPLACE VIEW `probe`.`v_GetTotalProbeCountUnique` AS
select count(*) as countUnique from probe WHERE count = 1;

-- -----------------------------------------------------
-- View `probe`.`v_ListUniqueProbeIds`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_ListUniqueProbeIds` ;
DROP TABLE IF EXISTS `probe`.`v_ListUniqueProbeIds`;
CREATE  OR REPLACE VIEW `probe`.`v_ListUniqueProbeIds` AS
select idprobe from probe WHERE count = 1;

-- -----------------------------------------------------
-- View `probe`.`v_ListOrganismsUniqueProbeId`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_ListOrganismsUniqueProbeId` ;
DROP TABLE IF EXISTS `probe`.`v_ListOrganismsUniqueProbeId`;
CREATE  OR REPLACE VIEW `probe`.`v_ListOrganismsUniqueProbeId` AS
SELECT coordinates.idOrganism, coordinates.idProbe as probeID, count(*) as total 
FROM coordinates 
GROUP BY idProbe
ORDER BY idOrganism, idProbe;

-- -----------------------------------------------------
-- View `probe`.`v_ListOrganismsUniqueProbeIdTotalUnique`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_ListOrganismsUniqueProbeIdTotalUnique` ;
DROP TABLE IF EXISTS `probe`.`v_ListOrganismsUniqueProbeIdTotalUnique`;
CREATE  OR REPLACE VIEW `probe`.`v_ListOrganismsUniqueProbeIdTotalUnique` AS
SELECT v_ListOrganismsUniqueProbeId.probeID, count(*) as total 
FROM v_ListOrganismsUniqueProbeId GROUP BY probeID HAVING total = 1 ORDER BY probeID;


-- -----------------------------------------------------
-- View `probe`.`v_ListUniqueAnalisedProbes`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_ListUniqueAnalisedProbes` ;
DROP TABLE IF EXISTS `probe`.`v_ListUniqueAnalisedProbes`;
CREATE  OR REPLACE VIEW `probe`.`v_ListUniqueAnalisedProbes` AS
	SELECT v_ListOrganismsUniqueProbeIdTotalUnique.probeId, 
		probe.sequenceLig as sequenceLig, 
		probe.sequenceM13 as sequenceM13, 
		v_ListOrganismsUniqueProbeIdTotalUnique.total as TotalProbeAppearance
	FROM v_ListOrganismsUniqueProbeIdTotalUnique, probe
	WHERE (v_ListOrganismsUniqueProbeIdTotalUnique.probeId = probe.idprobe);

-- -----------------------------------------------------
-- View `probe`.`v_ListProbeCoreUniqueFromProbe`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_ListProbeCoreUniqueFromProbe` ;
DROP TABLE IF EXISTS `probe`.`v_ListProbeCoreUniqueFromProbe`;
CREATE  OR REPLACE VIEW `probe`.`v_ListProbeCoreUniqueFromProbe` AS
select CONCAT(SUBSTRING(sequenceLig, -10), SUBSTRING(sequencem13, 1, 10)) AS ligant, count(*) as count FROM probe GROUP BY ligant HAVING count = 1;

-- -----------------------------------------------------
-- View `probe`.`v_originalFinal`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `probe`.`v_originalFinal` ;
DROP TABLE IF EXISTS `probe`.`v_originalFinal`;
CREATE  OR REPLACE VIEW `probe`.`v_originalFinal` AS
	SELECT organism.nameOrganism, organism.taxonId, organism.variant, organism.sequenceTypeId,
	chromossomes.chromossomeLongName, 
	coordinates.startLig, coordinates.startM13, coordinates.endM13,  coordinates.strand, coordinates.derivated,
	probe.sequenceLig, probe.sequenceM13, 
	probe.probeGc, probe.probeTm, probe.idprobe
	FROM organism, chromossomes, coordinates, probe
	WHERE (coordinates.idOrganism   = organism.idorganism 
		AND coordinates.idProbe = probe.idprobe 
		AND coordinates.chromossome = chromossomes.idChromossome) 
		HAVING idprobe IN (SELECT probeID FROM v_ListUniqueAnalisedProbes);


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
