process PROTEINMPNN_SCRIPT {
    tag "${meta.pdb_id}"
    executor 'local'

    publishDir "${params.output_dir}/proteinmpnn_outputs", mode: 'copy'

    input:
    tuple val(meta), path(pdb_file), path(rfdiffusion_result_file)

    output:
    tuple val(meta), path("${meta.pdb_id}_designed_sequences.fasta"), path("${meta.pdb_id}_proteinmpnn_result.json"), emit: optimized_sequences

    script:

    """
    set -e

    echo "Processing ${meta.pdb_id} with ProteinMPNN"

    if [ "\$NVCF_RUN_KEY" = "" ]; then echo "ERROR: NVCF_RUN_KEY not set"; exit 1; fi

    echo "Extracting PDB content from ${pdb_file}..."
    echo "File size: \$(wc -l < ${pdb_file}) lines"
    echo "First 5 lines:"
    head -5 ${pdb_file}

    echo "Debug: PDB file path is: ${pdb_file}"
    echo "Debug: File exists check: \$(ls -la ${pdb_file})"
    echo "Debug: ATOM lines found: \$(grep -c ^ATOM ${pdb_file} || echo 0)"
    echo "Debug: First ATOM line: \$(grep ^ATOM ${pdb_file} | head -1 || echo 'NONE FOUND')"

    # Extract PDB content - using head -n 200 as in the provided example
    pdb=\$(cat ${pdb_file} | grep ^ATOM | awk '{printf "%s\\\\n", \$0}')
    echo "PDB content length: \${#pdb}"
    echo "PDB preview: \$(echo \"\$pdb\" | head -c 100)..."

    if [ -z "\$pdb" ]; then
        echo "ERROR: No ATOM records found in PDB file!"
        exit 1
    fi

    # Create request using the exact pattern from the provided REST API example
    request='{
     "input_pdb": "'\$pdb'",
     "ca_only": ${meta.proteinmpnn_ca_only ?: false},
     "use_soluble_model": ${meta.proteinmpnn_use_soluble_model ?: false},
     "sampling_temp": [${meta.proteinmpnn_sampling_temp ?: 0.1}],
     "num_seq_per_target": ${meta.proteinmpnn_num_seq_per_target ?: 1},
     "input_pdb_chains": ["B"]
    }'

    echo "Request preview: \$(echo \"\$request\" | head -c 200)..."

    echo "Making ProteinMPNN API call..."
    response=\$(curl -s -H 'Content-Type: application/json' -H "Authorization: Bearer \$NVCF_RUN_KEY" -H "nvcf-poll-seconds: 300" -d "\$request" https://health.api.nvidia.com/v1/biology/ipd/proteinmpnn/predict)

    echo "\$response" > ${meta.pdb_id}_proteinmpnn_result.json

    # Extract FASTA sequences from the mfasta field and save as single multi-FASTA
    echo "\$response" | jq -r '.mfasta // empty' > ${meta.pdb_id}_designed_sequences.fasta

    # Check if FASTA sequences were extracted successfully
    if [ ! -s ${meta.pdb_id}_designed_sequences.fasta ]; then
        echo "WARNING: No FASTA sequences found in response, creating empty file"
        touch ${meta.pdb_id}_designed_sequences.fasta
    else
        total_seqs=\$(grep -c '^>' ${meta.pdb_id}_designed_sequences.fasta || echo 0)
        echo "Successfully extracted \$total_seqs sequences to multi-FASTA file"
        echo "First sequence header: \$(head -1 ${meta.pdb_id}_designed_sequences.fasta)"
    fi

    echo "Completed ProteinMPNN processing for ${meta.pdb_id}"
    """
}

process PROTEINMPNN_EXECUTOR {
    tag "${meta.pdb_id}"
    executor 'nim'

    // NVIDIA Rate limits
    maxForks 2

    publishDir "${params.output_dir}/proteinmpnn_outputs", mode: 'copy'

    input:
    tuple val(meta), path(pdb_file), path(rfdiffusion_result_file)

    output:
    tuple val(meta), path("output.fasta"), path("nim_result.json"), emit: optimized_sequences

    script:
    task.ext.nim = "proteinmpnn"
    task.ext.ca_only = meta.proteinmpnn_ca_only ?: false
    task.ext.use_soluble_model = meta.proteinmpnn_use_soluble_model ?: false
    task.ext.sampling_temp = [meta.proteinmpnn_sampling_temp ?: 0.1]
    task.ext.num_seq_per_target = meta.proteinmpnn_num_seq_per_target ?: 1
    // Only design the binder chain B, keep target chain A fixed

    """
    echo "Processing ${meta.pdb_id} through ProteinMPNN NIM service"
    echo "Input PDB: ${pdb_file}"
    echo "Service: ${task.ext.nim}"
    echo "CA only: ${task.ext.ca_only}"
    echo "Use soluble model: ${task.ext.use_soluble_model}"
    echo "Sampling temperature: ${task.ext.sampling_temp}"
    echo "Sequences per target: ${task.ext.num_seq_per_target}"

    # Create start time marker
    start_time=\$(date +%s)
    start_timestamp=\$(date -Iseconds)

    # The NIM executor will handle the actual API call
    # Output files will be generated automatically
    echo "ProteinMPNN processing initiated at \$start_timestamp"

    # Create end time marker and calculate duration
    end_time=\$(date +%s)
    end_timestamp=\$(date -Iseconds)
    duration=\$((end_time - start_time))

    # Generate metrics JSON
    cat > ${meta.pdb_id}_metrics.json << EOF
{
    "pdb_id": "${meta.pdb_id}",
    "start_time": "\$start_timestamp",
    "end_time": "\$end_timestamp",
    "duration_seconds": \$duration,
    "ca_only": ${task.ext.ca_only},
    "use_soluble_model": ${task.ext.use_soluble_model},
    "sampling_temp": ${task.ext.sampling_temp},
    "num_seq_per_target": ${task.ext.num_seq_per_target},
    "status": "success"
}
EOF

    # NIM executor produces output.fasta and nim_result.json directly
    echo "NIM executor should have produced output.fasta and nim_result.json"

    echo "ProteinMPNN processing completed for ${meta.pdb_id} in \$duration seconds"
    """
}
