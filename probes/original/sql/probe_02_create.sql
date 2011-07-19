SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS `probe`;

CREATE SCHEMA IF NOT EXISTS `probe` DEFAULT CHARACTER SET latin1 ;
USE `probe`;

-- -----------------------------------------------------
-- Table `probe`.`organism`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `probe`.`organism` (
  `idorganism`     CHAR(9)      BINARY   NOT NULL ,
  `nameOrganism`   VARCHAR(100) BINARY   NOT NULL ,
  `taxonId`        INT          UNSIGNED NOT NULL ,
  `variant`        TINYINT      UNSIGNED NOT NULL ,
  `sequenceTypeId` TINYINT      UNSIGNED NOT NULL ,
  `count`          MEDIUMINT    UNSIGNED NOT NULL DEFAULT 1 ,
  PRIMARY KEY (`idorganism`) )
DEFAULT CHARACTER SET = latin1
ENGINE         = InnoDB
COLLATE        = latin1_bin
MIN_ROWS       = 200
AVG_ROW_LENGTH = 35
PACK_KEYS      = 1
ROW_FORMAT     = DYNAMIC;
-- KEY_BLOCK_SIZE = 8;

CREATE UNIQUE INDEX `organism_unique` ON `probe`.`organism` (`nameOrganism` ASC) ;


-- -----------------------------------------------------
-- Table `probe`.`chromossomes`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `probe`.`chromossomes` (
  `idChromossome`        INT         UNSIGNED NOT NULL AUTO_INCREMENT ,
  `idOrganism`           CHAR(9)     BINARY   NOT NULL ,
  `chromossomeNumber`    SMALLINT    UNSIGNED NOT NULL ,
  `chromossomeShortName` VARCHAR(50)          NOT NULL ,
  `chromossomeLongName`  VARCHAR(120)         NOT NULL ,
  PRIMARY KEY (`idChromossome`) )
DEFAULT CHARACTER SET = latin1
ENGINE         = InnoDB
COLLATE        = latin1_bin
MIN_ROWS       = 10000
AVG_ROW_LENGTH = 80
PACK_KEYS      = 1
ROW_FORMAT     = DYNAMIC;
-- KEY_BLOCK_SIZE = 8;

CREATE UNIQUE INDEX `chromossomeUniqueness` USING HASH ON `probe`.`chromossomes` (`idOrganism` ASC, `chromossomeNumber` ASC) ;


-- -----------------------------------------------------
-- Table `probe`.`sequenceType`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `probe`.`sequenceType` (
  `typeId`   TINYINT    UNSIGNED NOT NULL ,
  `typeName` MEDIUMTEXT          NOT NULL ,
  PRIMARY KEY (`typeId`) 
)
DEFAULT CHARACTER SET = latin1
ENGINE         = InnoDB
COLLATE        = latin1_bin
MIN_ROWS       = 10
AVG_ROW_LENGTH = 10
PACK_KEYS      = 1
ROW_FORMAT     = DYNAMIC;
-- KEY_BLOCK_SIZE = 8;

-- -----------------------------------------------------
-- Table `probe`.`complete`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `probe`.`complete` (
  `idCoordinates` INT         UNSIGNED NOT NULL AUTO_INCREMENT,
  `idOrganism`    CHAR(9)     BINARY   NOT NULL ,
  `startLig`      INT         UNSIGNED NOT NULL ,
  `startM13`      INT         UNSIGNED NOT NULL ,
  `endM13`        INT         UNSIGNED NOT NULL ,
  `strand`        CHAR(1)     BINARY   NOT NULL DEFAULT 'F' ,
  `chromossome`   MEDIUMINT   UNSIGNED NOT NULL ,
  `derivated`     TINYINT     UNSIGNED NOT NULL DEFAULT 0 ,
  `sequenceLig`   VARCHAR(40) BINARY   NOT NULL ,
  `sequenceLigGc` TINYINT     UNSIGNED NOT NULL ,
  `sequenceLigTm` TINYINT     UNSIGNED NOT NULL ,
  `sequenceM13`   VARCHAR(50) BINARY   NOT NULL ,
  `sequenceM13Gc` TINYINT     UNSIGNED NOT NULL ,
  `sequenceM13Tm` TINYINT     UNSIGNED NOT NULL ,
  `sequence`      VARCHAR(90) BINARY   NOT NULL ,
  `sequenceGc`    TINYINT     UNSIGNED NOT NULL ,
  `sequenceTm`    TINYINT     UNSIGNED NOT NULL ,
  `ligant`        CHAR(20)    BINARY   NOT NULL , 
  INDEX (`idCoordinates`),
  PRIMARY KEY (`idCoordinates`))
DEFAULT CHARACTER SET = latin1
ENGINE         = InnoDB
COLLATE        = latin1_bin
AVG_ROW_LENGTH = 120
MAX_ROWS       = 1000000000
MIN_ROWS       = 3000000
PACK_KEYS      = 1
KEY_BLOCK_SIZE = 8
ROW_FORMAT     = COMPRESSED;




-- CREATE INDEX `ORG` ON `probe`.`complete` (`idOrganism` ASC) ;

-- CREATE INDEX `LIG` ON `probe`.`complete` (`sequenceLig` ASC) ;

-- CREATE INDEX `M13` ON `probe`.`complete` (`sequenceM13` ASC) ;

-- CREATE INDEX `SEQ` ON `probe`.`complete` (`sequence` ASC) ;

-- CREATE INDEX `LIGANT` ON `probe`.`complete` (`ligant` ASC) ;




-- -----------------------------------------------------
-- Table `probe`.`complete`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`complete` (
--   `idCoordinates` INT         UNSIGNED NOT NULL AUTO_INCREMENT,
--   `idProbe`       VARCHAR(20) BINARY   NOT NULL ,
--   `idOrganism`    CHAR(9)     BINARY   NOT NULL ,
--   `startLig`      INT         UNSIGNED NOT NULL ,
--   `startM13`      INT         UNSIGNED NOT NULL ,
--   `endM13`        INT         UNSIGNED NOT NULL ,
--   `strand`        CHAR(1)     BINARY   NOT NULL DEFAULT 'F' ,
--   `chromossome`   MEDIUMINT   UNSIGNED NOT NULL ,
--   `derivated`     TINYINT     UNSIGNED NOT NULL DEFAULT 0 ,
--  INDEX (`idProbe`),
--   PRIMARY KEY (`idCoordinates`)
-- )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- AVG_ROW_LENGTH = 45
-- MAX_ROWS       = 1000000000
-- MIN_ROWS       = 3000000
-- PACK_KEYS      = 1
-- ROW_FORMAT     = DYNAMIC;



-- -----------------------------------------------------
-- Table `probe`.`uniq_Lig`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`uniq_Lig` (
--   `idProbe`       VARCHAR(20) BINARY   NOT NULL ,
--   `sequenceLig`   VARCHAR(15) BINARY   NOT NULL ,
--   `sequenceLigGc` TINYINT     UNSIGNED NOT NULL ,
--   `sequenceLigTm` TINYINT     UNSIGNED NOT NULL ,
--  INDEX (`sequenceLig`),
--   PRIMARY KEY (`idProbe`)
-- )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- AVG_ROW_LENGTH = 30
-- MAX_ROWS       = 1000000000
-- MIN_ROWS       = 3000000
-- PACK_KEYS      = 1
-- ROW_FORMAT     = DYNAMIC;



-- -----------------------------------------------------
-- Table `probe`.`uniq_M13`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`uniq_M13` (
--   `idProbe`       VARCHAR(20) BINARY   NOT NULL ,
--   `sequenceM13`   VARCHAR(25) BINARY   NOT NULL ,
--   `sequenceM13Gc` TINYINT     UNSIGNED NOT NULL ,
--   `sequenceM13Tm` TINYINT     UNSIGNED NOT NULL ,
--  INDEX (`sequenceM13`),
--   PRIMARY KEY (`idProbe`)
-- )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- AVG_ROW_LENGTH = 30
-- MAX_ROWS       = 1000000000
-- MIN_ROWS       = 3000000
-- PACK_KEYS      = 1
-- ROW_FORMAT     = DYNAMIC;



-- -----------------------------------------------------
-- Table `probe`.`uniq_Sequence`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`uniq_Sequence` (
--   `idProbe`       VARCHAR(20) BINARY   NOT NULL ,
--   `sequence`      VARCHAR(35) BINARY   NOT NULL ,
--   `sequenceGc`    TINYINT     UNSIGNED NOT NULL ,
--   `sequenceTm`    TINYINT     UNSIGNED NOT NULL ,
--  INDEX (`sequence`),
--   PRIMARY KEY (`idProbe`)
-- )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- AVG_ROW_LENGTH = 30
-- MAX_ROWS       = 1000000000
-- MIN_ROWS       = 3000000
-- PACK_KEYS      = 1
-- ROW_FORMAT     = DYNAMIC;



-- -----------------------------------------------------
-- Table `probe`.`uniq_Ligant`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`uniq_Ligant` (
--   `idProbe`       VARCHAR(20) BINARY   NOT NULL ,
--   `ligant`        CHAR(8)     BINARY   NOT NULL , 
--  INDEX (`ligant`),
--   PRIMARY KEY (`idProbe`)
-- )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- AVG_ROW_LENGTH = 30
-- MAX_ROWS       = 1000000000
-- MIN_ROWS       = 3000000
-- PACK_KEYS      = 1
-- ROW_FORMAT     = DYNAMIC;



-- -----------------------------------------------------
-- Table `probe`.`coordinates`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`coordinates` (
--   `idCoordinates` INT       UNSIGNED NOT NULL AUTO_INCREMENT ,
--   `idOrganism`    INT       UNSIGNED NOT NULL ,
--   `idProbe`       INT       UNSIGNED NOT NULL ,
--   `startLig`      INT       UNSIGNED NOT NULL ,
--   `startM13`      INT       UNSIGNED NOT NULL ,
--   `endM13`        INT       UNSIGNED NOT NULL ,
--   `strand`        CHAR(1)   BINARY   NOT NULL DEFAULT 'F' ,
--   `chromossome`   MEDIUMINT UNSIGNED NOT NULL ,
--   `count`         MEDIUMINT UNSIGNED NOT NULL DEFAULT 1 ,
--   `derivated`     TINYINT   UNSIGNED NOT NULL DEFAULT 0 ,
--   PRIMARY KEY (`idCoordinates`, `idOrganism`, `idProbe`) )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- MIN_ROWS       = 3000000
-- AVG_ROW_LENGTH = 15
-- PACK_KEYS      = 1
-- ROW_FORMAT     = COMPRESSED;

-- CREATE UNIQUE INDEX `coordinates_uniqueness` USING HASH ON `probe`.`coordinates` (`idOrganism` ASC, `chromossome` ASC, `idProbe` ASC, `startLig` ASC, `endM13` ASC) ;


-- -----------------------------------------------------
-- Table `probe`.`probe`
-- -----------------------------------------------------
-- CREATE  TABLE IF NOT EXISTS `probe`.`probe` (
--   `idprobe`     INT         UNSIGNED NOT NULL AUTO_INCREMENT ,
--   `sequenceLig` VARCHAR(15) BINARY   NOT NULL ,
--   `sequenceM13` VARCHAR(20) BINARY   NOT NULL ,
--   `probeGc`     TINYINT     UNSIGNED NOT NULL ,
--   `probeTm`     TINYINT     UNSIGNED NOT NULL ,
--   `count`       MEDIUMINT   UNSIGNED NOT NULL DEFAULT 1 ,
--   PRIMARY KEY (`idprobe`) )
-- DEFAULT CHARACTER SET = latin1
-- ENGINE         = InnoDB
-- COLLATE        = latin1_bin
-- AVG_ROW_LENGTH = 40
-- MAX_ROWS       = 60
-- MIN_ROWS       = 20
-- PACK_KEYS      = 1
-- ROW_FORMAT     = COMPRESSED;

-- CREATE UNIQUE INDEX `sequence_unique` USING HASH ON `probe`.`probe` (`sequenceLig` ASC, `sequenceM13` ASC) ;



SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
