import os
import pytest
import glob

from VcfFilter import VcfFilter

# test_vcfFilter.py

@pytest.fixture
def vcf_object():
    '''Returns an  object'''
    vcf_file = pytest.config.getoption("--vcf")
    bcftools_folder = pytest.config.getoption("--bcftools_folder")
    vcf_object=VcfFilter(vcf=vcf_file,bcftools_folder=bcftools_folder)
    return vcf_object

@pytest.fixture
def clean_tmp():
    yield
    print("Cleanup files")
    files = glob.glob('data/outdir/*')
    for f in files:
        os.remove(f)

def test_filter_by_variant_type(vcf_object):
    '''
    Test method filter_by_variant_type
    Will select SNPs from the VCF file
    '''
    
    outfile=vcf_object.filter_by_variant_type(outprefix='data/outdir/test')

    assert os.path.isfile(outfile) is True


def test_filter_by_variant_type_biallelic(vcf_object):
    '''
    Test method filter_by_variant_type 
    using the biallelic option
    '''

    outfile=vcf_object.filter_by_variant_type(outprefix='data/outdir/test', biallelic=True)

    assert os.path.isfile(outfile) is True

def test_filter_by_variant_type_biallelic_compressed(vcf_object, clean_tmp):
    '''
    Test method filter_by_variant_type
    using the biallelic option
    '''

    outfile=vcf_object.filter_by_variant_type(outprefix='data/outdir/test', biallelic=True, compress=False)

    assert os.path.isfile(outfile) is True
