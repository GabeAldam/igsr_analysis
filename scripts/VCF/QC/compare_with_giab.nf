#!/usr/bin/env nextflow

/* 
 * VCF benchmarking using GIAB (Genome in a Bottle)
 * This workflow relies on Nextflow (see https://www.nextflow.io/tags/workflow.html)
 *
 * @author
 * Ernesto Lowy <ernesto.lowy@gmail.com>
 *
 */

// params defaults
params.help = false
params.calc_gtps = false

//print usage
if (params.help) {
    log.info ''
    log.info 'Pipeline to benchmark a VCF using GIAB'
    log.info '--------------------------------------'
    log.info ''
    log.info 'Usage: '
    log.info '    nextflow compare_with_giab.nf --vcf VCF --chros chr20 --vt snps'
    log.info ''
    log.info 'Options:'
    log.info '	--help	Show this message and exit.'
    log.info '	--vcf VCF    Path to the VCF file that will be assessed.'
    log.info '  --giab VCF   Path to the GIAB VCF that will be used as the TRUE call set.'
    log.info '  --vt  VARIANT_TYPE   Type of variant to benchmark. Possible values are 'snps'/'indels'.'
    log.info '  --chros CHROSTR	  Chromosomes that will be analyzed: chr20 or chr1,chr2.'
    log.info '  --calc_gtps BOOL  If true, then calculte the genotype concordance between params.vcf'
    log.info '                    and params.giab. If true, the compared VCFs should contain genotype'
    log.info '                    information.' 
    log.info ''
    exit 1
}

process excludeNonVariants {
	/*
	This process will select the variants sites on the desired chromosomes.
	Additionally, only the biallelic variants with the 'PASS' label in the filter column are considered

	Returns
	-------
	Path to a VCF file containing just the filtered sites
	*/

	memory '500 MB'
        executor 'lsf'
        queue "${params.queue}"
        cpus 1

	output:
        file 'out.sites.vcf.gz' into out_sites_vcf

	"""
	${params.bcftools_folder}/bcftools view -G -m2 -M2 -c1 ${params.vcf} -f.,PASS -r ${params.chros} -o out.sites.vcf.gz -Oz
	${params.tabix} out.sites.vcf.gz
	"""
}


process excludeNonValid {
	/*
	This process will exclude the regions defined in a .BED file file from out_sites_vcf
	*/

	memory '500 MB'
        executor 'lsf'
        queue "${params.queue}"
        cpus 1

	input:
	file out_sites_vcf

	output:
	file 'out.sites.nonvalid.vcf.gz' into out_sites_nonvalid_vcf

	"""
	${params.bcftools_folder}/bcftools view -T ^${params.non_valid_regions} ${out_sites_vcf} -o out.sites.nonvalid.vcf.gz -Oz
	tabix out.sites.nonvalid.vcf.gz
	"""
}


process selectVariants {
	/*
	Process to select the variants from out_sites_nonvalid_vcf
	*/

	memory '500 MB'
        executor 'lsf'
        queue "${params.queue}"
        cpus 1

	input:
	file out_sites_nonvalid_vcf

	out_sites_nonvalid = 'out.sites.nonvalid.'+ params.vt +'.vcf.gz'

	output:
	file "out.sites.nonvalid.${params.vt}.vcf.gz" into out_sites_nonvalid_vts
	
	"""
	${params.bcftools_folder}/bcftools view -v ${params.vt} ${out_sites_nonvalid_vcf} -o out.sites.nonvalid.${params.vt}.vcf.gz -O z
	"""
}

process intersecionCallSets {
	/*
	Process to find the intersection between out_sites_nonvalid_vts and GIAB call set
	*/

	memory '500 MB'
        executor 'lsf'
        queue "${params.queue}"
        cpus 1

	input:
	file out_sites_nonvalid_vts

	output:
	file 'dir/' into out_intersect

	"""
	tabix ${out_sites_nonvalid_vts}
	${params.bcftools_folder}/bcftools isec -c ${params.vt} -p 'dir/' ${out_sites_nonvalid_vts} ${params.giab}
	"""
}

process compressIntersected {
	/*
	Process to compress the files generated by bcftools isec
	and to run BCFTools stats on these files
	*/
	publishDir 'results_'+params.chros, mode: 'copy', overwrite: true

	memory '500 MB'
        executor 'lsf'
        queue "${params.queue}"
        cpus 1

	input:
	file out_intersect

	output:
	file 'FP.vcf.gz' into fp_vcf
	file 'FN.vcf.gz' into fn_vcf
	file 'TP_igsr.vcf.gz' into tp_igsr_vcf
	file 'TP_giab.vcf.gz' into tp_giab_vcf
	file 'FP.stats' into fp_stats
	file 'FN.stats' into fn_stats
	file 'TP.stats' into tp_stats

	"""
	${params.bgzip} -c ${out_intersect}/0000.vcf > FP.vcf.gz
	${params.bcftools_folder}/bcftools stats ${out_intersect}/0000.vcf > FP.stats 
	${params.bgzip} -c ${out_intersect}/0001.vcf > FN.vcf.gz
	${params.bcftools_folder}/bcftools stats ${out_intersect}/0001.vcf > FN.stats
	${params.bgzip} -c ${out_intersect}/0002.vcf > TP_igsr.vcf.gz
	${params.bcftools_folder}/bcftools stats ${out_intersect}/0002.vcf > TP.stats
	${params.bgzip} -c ${out_intersect}/0003.vcf > TP_giab.vcf.gz
	"""
}

process selectInHighConf {
	/*
	Process to select the variants in the intersected call sets
	that are in high confidence regions as defined in GIAB.

	This process will also convert tp_igsr_highconf_vcf and tp_giab_highconf_vcf into .tsv files.
	This step is necessary for calculating the genotype concordance in the next process
	*/
	publishDir 'results_'+params.chros, mode: 'copy', overwrite: true
	
	memory '500 MB'
        executor 'lsf'
        queue "${params.queue}"
        cpus 1

	input:
	file fp_vcf
	file fn_vcf
	file tp_igsr_vcf
	file tp_giab_vcf

	output:
	file 'FP.highconf.vcf.gz' into fp_highconf_vcf
	file 'FN.highconf.vcf.gz' into fn_highconf_vcf
	file 'TP_igsr.highconf.vcf.gz' into tp_igsr_highconf_vcf
	file 'TP_giab.highconf.vcf.gz' into tp_giab_highconf_vcf
	file 'TP_igsr.highconf.vcf.gz.tbi' into tp_igsr_highconf_vcf_tbi
	file 'TP_giab.highconf.vcf.gz.tbi' into tp_giab_highconf_vcf_tbi
	file 'FP.highconf.stats' into fp_highconf_stats
	file 'FN.highconf.stats' into fn_highconf_stats
	file 'TP.highconf.stats' into tp_highconf_stats
	file 'igsr.tsv' into igsr_tsv
	file 'giab.tsv' into giab_tsv

	"""
	tabix ${fp_vcf}
	tabix ${fn_vcf}
	tabix ${tp_igsr_vcf}
	tabix ${tp_giab_vcf}
	${params.bcftools_folder}/bcftools view -R ${params.high_conf_regions} ${fp_vcf} -o FP.highconf.vcf.gz -Oz
	${params.bcftools_folder}/bcftools stats FP.highconf.vcf.gz > FP.highconf.stats
	${params.bcftools_folder}/bcftools view -R ${params.high_conf_regions} ${fn_vcf} -o FN.highconf.vcf.gz -Oz
	${params.bcftools_folder}/bcftools stats FN.highconf.vcf.gz > FN.highconf.stats
	${params.bcftools_folder}/bcftools view -R ${params.high_conf_regions} ${tp_igsr_vcf} -o TP_igsr.highconf.vcf.gz -Oz
	${params.bcftools_folder}/bcftools stats TP_igsr.highconf.vcf.gz > TP.highconf.stats
	${params.bcftools_folder}/bcftools view -R ${params.high_conf_regions} ${tp_giab_vcf} -o TP_giab.highconf.vcf.gz -Oz
	tabix TP_igsr.highconf.vcf.gz
	tabix TP_giab.highconf.vcf.gz
	${params.bcftools_folder}/bcftools query -f \'[%POS\\t%REF\\t%ALT\\t%GT\\n]\' TP_giab.highconf.vcf.gz > giab.tsv
	${params.bcftools_folder}/bcftools query -f \'[%POS\\t%REF\\t%ALT\\t%GT\\n]\' TP_igsr.highconf.vcf.gz > igsr.tsv
	"""
}

// activate this process only if params.vcf has genotype information
if (params.calc_gtps==true) {

   process calculateGTconcordance {
   	   /*
	   Process to calculate the genotype concordance between the files
	   */
	   publishDir 'results_'+params.chros, mode: 'copy', overwrite: true

	   memory '500 MB'
           executor 'lsf'
           queue "${params.queue}"
           cpus 1

	   input:
	   file igsr_tsv
	   file giab_tsv

	   output:
	   file 'GT_concordance.txt' into gt_conc

	   """
	   python ${params.igsr_root}/scripts/VCF/QC/calc_gtconcordance.py ${igsr_tsv} ${giab_tsv} > GT_concordance.txt
	   """
   }
}