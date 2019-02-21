#!/usr/bin/env nextflow

params.sra_ids = "$baseDir/data/sra_ids.txt.100"
params.reference = "$baseDir/data/reference.fa"
params.outdir = "$baseDir/results"

/*
 * The reference genome file
 */
reference_file = file(params.reference)

ids = Channel
        .fromPath(params.sra_ids)
        .splitText()
        .map{it -> it.trim()}


process buildIndex {
    input:
    file reference from reference_file
      
    output:
    file '*.index*' into reference_index
        
    """
    bowtie2-build ${reference} ${reference}.index
    """
}

process search {
    input:
    file reference from reference_file
    file index from reference_index
    val id from ids
   
    output:
    set '*.bam', '*.bai' into bam_files
    
    shell:    
    """
    pwd
    ls -l

    # check wrangler cache first
    WRANGLER_LOC=/nas/wrangler/NCBI/SRA/Downloads/fastq/${id}.fastq.gz
    if [ -e \$WRANGLER_LOC ]; then
        SRA_SOURCE="\$WRANGLER_LOC"
        echo "Will read ${id} from \$WRANGLER_LOC"
    else
        # not found - we should log this better
        echo "WARNING: ${id} not found on Wrangler - skipping..."
        continue 
    fi

    bowtie2 -p 1 -q --no-unal -x ${reference}.index -U \$SRA_SOURCE | samtools view -bS - | samtools sort - ${id}

    samtools index ${id}.bam

    rm -f \$HOME/ncbi/public/sra/{id}.sra*

    # need to wait a little bit as nextflow is not happy with the filesystem latency
    sleep 2m

    """
}


process collect_outputs {
    publishDir "$params.outdir"
    input:
    file '*' from bam_files.collect()
   
    output:
    file '*.zip' into final_outputs
    
    shell:    
    """
    zip -r results . -i '*.bam' -i '*.bai'
    """
}

