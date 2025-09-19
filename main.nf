#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Import process definitions
include { samplesheetToList }    from 'plugin/nf-schema'
include { RFDIFFUSION_SCRIPT }   from './modules/rfdiffusion.nf'
include { RFDIFFUSION_EXECUTOR } from './modules/rfdiffusion.nf'
include { PROTEINMPNN_SCRIPT } from './modules/proteinmpnn.nf'
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
    rfdiffusion_script_results = RFDIFFUSION_SCRIPT(pdb_channel)
    // rfdiffusion_executor_results = RFDIFFUSION_EXECUTOR(pdb_channel)

    // Run ProteinMPNN
    proteinmpnn_results = PROTEINMPNN_SCRIPT(rfdiffusion_script_results.generated_structures)

    // Transform ProteinMPNN results to create individual FASTA channels for parallel Boltz2 processing
    proteinmpnn_results.optimized_sequences
        .map { meta, fasta_files, _json_file ->
            // Create a list of [meta, individual_fasta_file] for each FASTA file
            def individual_fastas = []
            fasta_files.each { fasta_file ->
                individual_fastas << [meta, fasta_file]
            }
            return individual_fastas
        }
        .flatten()  // Flatten the list of lists into individual items
        .collate(2)  // Group back into pairs of [meta, fasta_file]
        .set { individual_fasta_channel }

    // Debug the individual FASTA channel before joining
    individual_fasta_channel.view { "Individual FASTA before join: $it" }

    // Join individual FASTA sequences with original PDB files for complex prediction
    // Use combine and filter to match by pdb_id (more reliable than join for this case)
    individual_fasta_channel
        .combine(pdb_channel)
        .filter { meta_fasta, fasta_file, meta_pdb, pdb_file ->
            // Only keep combinations where pdb_id matches
            meta_fasta.pdb_id == meta_pdb.pdb_id
        }
        .map { meta_fasta, fasta_file, meta_pdb, pdb_file ->
            // Return [meta, fasta_file, pdb_file]
            [meta_fasta, fasta_file, pdb_file]
        }
        .set { complex_channel }

    complex_channel.view { "Complex channel: $it" }

    // Run Boltz2 on each complex (ProteinMPNN sequence + original PDB)
    boltz2_results = BOLTZ2_SCRIPT(complex_channel)
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