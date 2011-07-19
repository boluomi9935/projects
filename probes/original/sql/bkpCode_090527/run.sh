#!/bin/sh
echo "::::::::::::::::::::::::::::::::::::::::"
echo "RUNNING OVER 36 FILES:"
echo "	Ashbya_gossypii_ATCC_10895_CHROMOSSOMES.fasta"
echo "	Aspergillus_clavatus_NRRL_1_CHROMOSSOMES.fasta"
echo "	Aspergillus_flavus_NRRL3357_CHROMOSSOMES.fasta"
echo "	Aspergillus_fumigatus_Af293_CHROMOSSOMES.fasta"
echo "	Aspergillus_nidulans_FGSC_A4_CHROMOSSOMES.fasta"
echo "	Aspergillus_niger_CBS513.88_CHROMOSSOMES.fasta"
echo "	Aspergillus_oryzae_RIB40_CHROMOSSOMES.fasta"
echo "	Aspergillus_terreus_NIH2624_CHROMOSSOMES.fasta"
echo "	Batrachochytrium_dendrobatidis_JEL423_CHROMOSSOMES.fasta"
echo "	Candida_albicans_sc5314_assembly_21_1_CONTIGS.fasta"
echo "	Candida_albicans_wo1_1_CHROMOSSOMES.fasta"
echo "	Candida_dubliniensis_CD36_CHROMOSSOMES.fasta"
echo "	Candida_glabrata_CBS138_CHROMOSSOMES.fasta"
echo "	Candida_guilliermondii_1_CHROMOSSOMES.fasta"
echo "	Candida_lusitaniae_1_CHROMOSSOMES.fasta"
echo "	Candida_parapsilosis_1_CONTIGS.fasta"
echo "	Candida_tropicalis_3_CHROMOSSOMES.fasta"
echo "	Clavispora_lusitaniae_ATCC42720_WGS_SCAFFOLD.fasta"
echo "	Cryptococcus_gattii_R265_CHROMOSSOMES.fasta"
echo "	Cryptococcus_gattii_WM276_GENES.fasta"
echo "	Cryptococcus_neoformans_var_grubii_H99_SCAFFOLD.fasta"
echo "	Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta"
echo "	Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta"
echo "	Debaryomyces_hansenii_CBS767_CHROMOSSOMES.fasta"
echo "	Encephalitozoon_cuniculi_GB-M1_CHROMOSSOMES.fasta"
echo "	Kluyveromyces_lactis_NRRL_Y-1140_CHROMOSSOMES.fasta"
echo "	Kluyveromyces_thermotolerans_CBS6340_CHROMOSSOMES.fasta"
echo "	Lodderomyces_elongisporus_YB-4239_CHROMOSSOMES.fasta"
echo "	Neurospora_crassa_OR74A_SCAFFOLD.fasta"
echo "	Pichia_stipitis_CBS6054_CHROMOSSOMES.fasta"
echo "	Plasmodium_falciparum_CHROMOSSOMES.fasta"
echo "	Saccharomyces_cerevisiae_CHROMOSSOMES.fasta"
echo "	Saccharomyces_kluyveri_NRRL_Y12651_CHROMOSSOMES.fasta"
echo "	Schizosaccharomyces_pombe_CHROMOSSOMES.fasta"
echo "	Yarrowia_lipolytica_strain_CLIB122_CHROMOSSOMES.fasta"
echo "	Zygosaccharomyces_rouxii_CBS732_CHROMOSSOMES.fasta"
echo "::::::::::::::::::::::::::::::::::::::::

"

echo "...................."
echo "OPTIMIZING"
echo "...................."
time sudo mysql -u probe < /home/saulo/Desktop/rolf/sql/probe_6_optimize.sql

echo "####################"
echo "RUNNING FILE 1 OUT OF 36	Ashbya_gossypii_ATCC_10895_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Ashbya_gossypii_ATCC_10895_CHROMOSSOMES.fasta 284811 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 1 OUT OF 36	Ashbya_gossypii_ATCC_10895_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 2 OUT OF 36	Aspergillus_clavatus_NRRL_1_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_clavatus_NRRL_1_CHROMOSSOMES.fasta 344612 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 2 OUT OF 36	Aspergillus_clavatus_NRRL_1_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 3 OUT OF 36	Aspergillus_flavus_NRRL3357_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_flavus_NRRL3357_CHROMOSSOMES.fasta 332952 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 3 OUT OF 36	Aspergillus_flavus_NRRL3357_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 4 OUT OF 36	Aspergillus_fumigatus_Af293_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_fumigatus_Af293_CHROMOSSOMES.fasta 330879 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 4 OUT OF 36	Aspergillus_fumigatus_Af293_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 5 OUT OF 36	Aspergillus_nidulans_FGSC_A4_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_nidulans_FGSC_A4_CHROMOSSOMES.fasta 227321 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 5 OUT OF 36	Aspergillus_nidulans_FGSC_A4_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 6 OUT OF 36	Aspergillus_niger_CBS513.88_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_niger_CBS513.88_CHROMOSSOMES.fasta 425011 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 6 OUT OF 36	Aspergillus_niger_CBS513.88_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 7 OUT OF 36	Aspergillus_oryzae_RIB40_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_oryzae_RIB40_CHROMOSSOMES.fasta 510516 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 7 OUT OF 36	Aspergillus_oryzae_RIB40_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 8 OUT OF 36	Aspergillus_terreus_NIH2624_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Aspergillus_terreus_NIH2624_CHROMOSSOMES.fasta 341663 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 8 OUT OF 36	Aspergillus_terreus_NIH2624_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 9 OUT OF 36	Batrachochytrium_dendrobatidis_JEL423_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Batrachochytrium_dendrobatidis_JEL423_CHROMOSSOMES.fasta 403673 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 9 OUT OF 36	Batrachochytrium_dendrobatidis_JEL423_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 10 OUT OF 36	Candida_albicans_sc5314_assembly_21_1_CONTIGS.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_albicans_sc5314_assembly_21_1_CONTIGS.fasta 237561 0 4 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 10 OUT OF 36	Candida_albicans_sc5314_assembly_21_1_CONTIGS.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 11 OUT OF 36	Candida_albicans_wo1_1_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_albicans_wo1_1_CHROMOSSOMES.fasta 294748 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 11 OUT OF 36	Candida_albicans_wo1_1_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 12 OUT OF 36	Candida_dubliniensis_CD36_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_dubliniensis_CD36_CHROMOSSOMES.fasta 573826 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 12 OUT OF 36	Candida_dubliniensis_CD36_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 13 OUT OF 36	Candida_glabrata_CBS138_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_glabrata_CBS138_CHROMOSSOMES.fasta 284593 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 13 OUT OF 36	Candida_glabrata_CBS138_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 14 OUT OF 36	Candida_guilliermondii_1_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_guilliermondii_1_CHROMOSSOMES.fasta 4929 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 14 OUT OF 36	Candida_guilliermondii_1_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 15 OUT OF 36	Candida_lusitaniae_1_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_lusitaniae_1_CHROMOSSOMES.fasta 36911 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 15 OUT OF 36	Candida_lusitaniae_1_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 16 OUT OF 36	Candida_parapsilosis_1_CONTIGS.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_parapsilosis_1_CONTIGS.fasta 5480 0 4 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 16 OUT OF 36	Candida_parapsilosis_1_CONTIGS.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 17 OUT OF 36	Candida_tropicalis_3_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Candida_tropicalis_3_CHROMOSSOMES.fasta 5482 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 17 OUT OF 36	Candida_tropicalis_3_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 18 OUT OF 36	Clavispora_lusitaniae_ATCC42720_WGS_SCAFFOLD.fasta"
echo "####################"
time ./probe_extractor.pl input Clavispora_lusitaniae_ATCC42720_WGS_SCAFFOLD.fasta 306902 0 9 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 18 OUT OF 36	Clavispora_lusitaniae_ATCC42720_WGS_SCAFFOLD.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 19 OUT OF 36	Cryptococcus_gattii_R265_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Cryptococcus_gattii_R265_CHROMOSSOMES.fasta 294750 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 19 OUT OF 36	Cryptococcus_gattii_R265_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 20 OUT OF 36	Cryptococcus_gattii_WM276_GENES.fasta"
echo "####################"
time ./probe_extractor.pl input Cryptococcus_gattii_WM276_GENES.fasta 367775 0 6 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 20 OUT OF 36	Cryptococcus_gattii_WM276_GENES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 21 OUT OF 36	Cryptococcus_neoformans_var_grubii_H99_SCAFFOLD.fasta"
echo "####################"
time ./probe_extractor.pl input Cryptococcus_neoformans_var_grubii_H99_SCAFFOLD.fasta 235443 0 9 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 21 OUT OF 36	Cryptococcus_neoformans_var_grubii_H99_SCAFFOLD.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 22 OUT OF 36	Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta 283643 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 22 OUT OF 36	Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 23 OUT OF 36	Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta 214684 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 23 OUT OF 36	Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 24 OUT OF 36	Debaryomyces_hansenii_CBS767_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Debaryomyces_hansenii_CBS767_CHROMOSSOMES.fasta 284592 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 24 OUT OF 36	Debaryomyces_hansenii_CBS767_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 25 OUT OF 36	Encephalitozoon_cuniculi_GB-M1_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Encephalitozoon_cuniculi_GB-M1_CHROMOSSOMES.fasta 284813 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 25 OUT OF 36	Encephalitozoon_cuniculi_GB-M1_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 26 OUT OF 36	Kluyveromyces_lactis_NRRL_Y-1140_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Kluyveromyces_lactis_NRRL_Y-1140_CHROMOSSOMES.fasta 284590 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 26 OUT OF 36	Kluyveromyces_lactis_NRRL_Y-1140_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 27 OUT OF 36	Kluyveromyces_thermotolerans_CBS6340_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Kluyveromyces_thermotolerans_CBS6340_CHROMOSSOMES.fasta 559295 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 27 OUT OF 36	Kluyveromyces_thermotolerans_CBS6340_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 28 OUT OF 36	Lodderomyces_elongisporus_YB-4239_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Lodderomyces_elongisporus_YB-4239_CHROMOSSOMES.fasta 379508 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 28 OUT OF 36	Lodderomyces_elongisporus_YB-4239_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 29 OUT OF 36	Neurospora_crassa_OR74A_SCAFFOLD.fasta"
echo "####################"
time ./probe_extractor.pl input Neurospora_crassa_OR74A_SCAFFOLD.fasta 367110 0 9 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 29 OUT OF 36	Neurospora_crassa_OR74A_SCAFFOLD.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 30 OUT OF 36	Pichia_stipitis_CBS6054_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Pichia_stipitis_CBS6054_CHROMOSSOMES.fasta 322104 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 30 OUT OF 36	Pichia_stipitis_CBS6054_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 31 OUT OF 36	Plasmodium_falciparum_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Plasmodium_falciparum_CHROMOSSOMES.fasta 5833 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 31 OUT OF 36	Plasmodium_falciparum_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 32 OUT OF 36	Saccharomyces_cerevisiae_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Saccharomyces_cerevisiae_CHROMOSSOMES.fasta 4932 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 32 OUT OF 36	Saccharomyces_cerevisiae_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 33 OUT OF 36	Saccharomyces_kluyveri_NRRL_Y12651_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Saccharomyces_kluyveri_NRRL_Y12651_CHROMOSSOMES.fasta 226302 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 33 OUT OF 36	Saccharomyces_kluyveri_NRRL_Y12651_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 34 OUT OF 36	Schizosaccharomyces_pombe_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Schizosaccharomyces_pombe_CHROMOSSOMES.fasta 4896 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 34 OUT OF 36	Schizosaccharomyces_pombe_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 35 OUT OF 36	Yarrowia_lipolytica_strain_CLIB122_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Yarrowia_lipolytica_strain_CLIB122_CHROMOSSOMES.fasta 4952 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 35 OUT OF 36	Yarrowia_lipolytica_strain_CLIB122_CHROMOSSOMES.fasta"
echo "********************


"


echo "####################"
echo "RUNNING FILE 36 OUT OF 36	Zygosaccharomyces_rouxii_CBS732_CHROMOSSOMES.fasta"
echo "####################"
time ./probe_extractor.pl input Zygosaccharomyces_rouxii_CBS732_CHROMOSSOMES.fasta 559307 0 2 
rm /mnt/ssd/probes/dumps/*.dump
/mnt/ssd/probes/insert.sh &
sleep 2
echo "********************"
echo "FINISH RUNNING FILE 36 OUT OF 36	Zygosaccharomyces_rouxii_CBS732_CHROMOSSOMES.fasta"
echo "********************


"


echo "...................."
echo "OPTIMIZING"
echo "...................."
time sudo mysql -u probe < /home/saulo/Desktop/rolf/sql/probe_6_optimize.sql

