SELECT organism.nameOrganism, chromossomes.chromossomeShortName, finalProbes.* FROM finalProbes, organism, chromossomes WHERE finalProbes.idOrganism = organism.idorganism and finalProbes.chromossome = chromossomes.idChromossome and finalProbes.idOrganism = chromossomes.idOrganism
