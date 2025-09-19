#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Import process definitions
include { samplesheetToList }    from 'plugin/nf-schema'
include { RFDIFFUSION_SCRIPT }   from './modules/rfdiffusion.nf'
include { RFDIFFUSION_EXECUTOR } from './modules/rfdiffusion.nf'
include { PROTEINMPNN_SCRIPT } from './modules/proteinmpnn.nf'
include { PROTEINMPNN_EXECUTOR } from './modules/proteinmpnn.nf'
include { BOLTZ2_SCRIPT } from './modules/boltz2.nf'

workflow {
    Channel
        .fromList(samplesheetToList(params.input, "assets/schema_input.json"))
        .set { pdb_list }

    // // Convert file to channel of PDB IDs and download PDB files using file()
    pdb_list
        .map { meta, pdb_id ->
            // Use Nextflow's built-in file() function to download from RCSB
            def pdb_file = file("https://files.rcsb.org/download/${pdb_id}.pdb", checkIfExists: true)
            return [meta + [pdb_id: pdb_id], pdb_file]
        }
        .set { pdb_channel }

    // Run RFdiffusion
    //rfdiffusion_results = RFDIFFUSION_SCRIPT(pdb_channel)
    rfdiffusion_results = RFDIFFUSION_EXECUTOR(pdb_channel)

    // Run ProteinMPNN
    //proteinmpnn_results = PROTEINMPNN_SCRIPT(rfdiffusion_script_results.generated_structures)
    proteinmpnn_results = PROTEINMPNN_EXECUTOR(rfdiffusion_results.generated_structures)

    // Split ProteinMPNN multi-FASTA into individual sequences (skip first sequence = original target)
    // and combine with original PDB files for Boltz2 complex prediction
    proteinmpnn_results.optimized_sequences
        .map { meta, multi_fasta, _json_file -> [meta, multi_fasta] }
        .splitFasta(record: [header: true, sequence: true])
        .groupTuple(by: 0)  // Group by meta to get all records per sample
        .flatMap { meta, records ->
            // Skip first record (original target) and emit individual records with design numbers
            records.drop(1).withIndex().collect { record, index ->
                def meta_with_design = meta + [design_number: index + 1]
                [meta_with_design, record]
            }
        }
        .combine(pdb_channel)
        .filter { meta_fasta, fasta_record, meta_pdb, _pdb_file ->
            meta_fasta.pdb_id == meta_pdb.pdb_id
        }
        .map { meta_fasta, fasta_record, _meta_pdb, pdb_file ->
            // Create temporary FASTA file from record for Boltz2
            def fasta_content = "${fasta_record.header}\n${fasta_record.sequence}"
            [meta_fasta, fasta_content, pdb_file]
        }
        .set { ch_multimer_fasta }

    // Run Boltz2 on each complex (ProteinMPNN sequence + original PDB)
    boltz2_results = BOLTZ2_SCRIPT(ch_multimer_fasta)
}

// workflow.onComplete {
//     log.info """
//     ===========================================
//     BATCH NIMS PROCESSING COMPLETED
//     ===========================================
//     Completion status: ${workflow.success ? 'SUCCESS' : 'FAILED'}
//     Completion time: ${workflow.complete}
//     Duration: ${workflow.duration}
//     Work directory: ${workflow.workDir}
//     Results directory: ${params.output_dir}
//     ===========================================
//     """
// }