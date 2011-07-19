CREATE TABLE probe.organism (
  idorganism INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  nameOrganism VARCHAR(255) NOT NULL,
  PRIMARY KEY(idorganism),
  UNIQUE INDEX organism_unique(nameOrganism)
)
TYPE=InnoDB
AVG_ROW_LENGTH = 50;

CREATE TABLE probe.probe (
  idprobe INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  sequence VARCHAR(255) NOT NULL,
  PRIMARY KEY(idprobe),
  UNIQUE INDEX sequence_unique(sequence)
)
TYPE=InnoDB;

CREATE TABLE probe.coordinates (
  idcoordinates INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  probe_idprobe INTEGER UNSIGNED NOT NULL,
  organism_idorganism INTEGER UNSIGNED NOT NULL,
  startLig INTEGER UNSIGNED NOT NULL,
  startM13 INTEGER UNSIGNED NOT NULL,
  endM13 INTEGER UNSIGNED NOT NULL,
  chromossome MEDIUMINT UNSIGNED NULL,
  PRIMARY KEY(idcoordinates, probe_idprobe, organism_idorganism),
  INDEX coordinates_organism(organism_idorganism),
  INDEX coordinates_probe(probe_idprobe),
  UNIQUE INDEX coordinates_uniqueness(probe_idprobe, organism_idorganism, startLig, startM13, endM13, chromossome),
  FOREIGN KEY Rel_03(organism_idorganism)
    REFERENCES organism(idorganism)
      ON DELETE NO ACTION
      ON UPDATE RESTRICT,
  FOREIGN KEY Rel_02(probe_idprobe)
    REFERENCES probe(idprobe)
      ON DELETE NO ACTION
      ON UPDATE RESTRICT
)
TYPE=InnoDB;

CREATE TABLE probe.fast (
  probe_idprobe INTEGER UNSIGNED NOT NULL,
  organism_idorganism INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY(probe_idprobe, organism_idorganism),
  INDEX fast_FKIndex1(organism_idorganism),
  INDEX fast_FKIndex2(probe_idprobe),
  FOREIGN KEY Rel_05(organism_idorganism)
    REFERENCES organism(idorganism)
      ON DELETE NO ACTION
      ON UPDATE RESTRICT,
  FOREIGN KEY Rel_04(probe_idprobe)
    REFERENCES probe(idprobe)
      ON DELETE NO ACTION
      ON UPDATE RESTRICT
)
TYPE=InnoDB;


