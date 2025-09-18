#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Import process definitions
include { samplesheetToList }    from 'plugin/nf-schema'
include { RFDIFFUSION_SCRIPT }   from './processes.nf'
include { RFDIFFUSION_EXECUTOR } from './processes.nf'


params.input = "${projectDir}/pdb_dataset_valid.csv"
params.max_structures = 200  // Limit for testing, set to 0 for all
params.rfdiffusion_batch_size = 10  // Process in batches to avoid overwhelming the API
params.output_dir = "results"


// Retry and error handling
params.max_retries = 3
params.retry_delay = 30  // seconds

workflow {
    Channel
        .fromList(samplesheetToList(params.input, "assets/schema_input.json"))
        .set { pdb_list }
    // pdb_id_channel.view()
        

    // // Convert file to channel of PDB IDs and download PDB files using file()
    pdb_list
        .map { meta, pdb_id ->
            // Use Nextflow's built-in file() function to download from RCSB
            def pdb_file = file("https://files.rcsb.org/download/${pdb_id}.pdb", checkIfExists: true)
            return [meta + [pdb_id: pdb_id], pdb_file]
        }
        .set { pdb_channel }

    // // Run RFdiffusion
    rfdiffusion_results = RFDIFFUSION_SCRIPT(pdb_channel)
    rfdiffusion_results = RFDIFFUSION_EXECUTOR(pdb_channel)
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