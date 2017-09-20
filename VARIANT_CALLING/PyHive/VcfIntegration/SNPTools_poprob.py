import eHive
import os
from VcfIntegration import VcfIntegration

class SNPTools_poprob(eHive.BaseRunnable):
    """Run SNPTools poprob on a VCF containing biallelic SNPs"""
    
    def run(self):
       vcf_g=VcfIntegration(vcf=self.param_required('vcf_file'),snptools_folder=self.param_required('snptools_folder'))

       outprefix=os.path.split(self.param_required('outprefix'))[1]
       
       prob_f=""
       if self.param_is_defined('verbose'):
           prob_f=vcf_g.run_snptools_poprob(outprefix=outprefix, rawlist=self.param_required('rawlist'), outdir=self.param_required('work_dir'), verbose=True)
       else:
           prob_f=vcf_g.run_snptools_poprob(outprefix=outprefix, rawlist=self.param_required('rawlist'), outdir=self.param_required('work_dir'), verbose=False)
       
       self.param('prob_f', prob_f)

    def write_output(self):
        self.warning('Work is done!')

        self.dataflow( {'prob_f' : self.param('prob_f') }, 1)

