process PROTEINMPNN_SCRIPT {
    tag "${meta.pdb_id}"
    executor 'local'

    // NVIDIA Rate limits
    maxForks 2

    errorStrategy 'retry'
    maxRetries 3

    publishDir "${params.output_dir}/proteinmpnn_outputs", mode: 'copy'

    input:
    tuple val(meta), path(pdb_file), path(rfdiffusion_result_file)

    output:
    tuple val(meta), path("${meta.pdb_id}_seq_*.fasta"), path("${meta.pdb_id}_proteinmpnn_result.json"), emit: optimized_sequences

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
     "num_seq_per_target": ${meta.proteinmpnn_num_seq_per_target ?: 1}
    }'

    echo "Request preview: \$(echo \"\$request\" | head -c 200)..."

    echo "Making ProteinMPNN API call..."
    response=\$(curl -s -H 'Content-Type: application/json' -H "Authorization: Bearer \$NVCF_RUN_KEY" -H "nvcf-poll-seconds: 300" -d "\$request" https://health.api.nvidia.com/v1/biology/ipd/proteinmpnn/predict)

    echo "\$response" > ${meta.pdb_id}_proteinmpnn_result.json

    # Extract FASTA sequences from the mfasta field
    echo "\$response" | jq -r '.mfasta // empty' > temp_sequences.fasta

    # Check if FASTA sequences were extracted successfully
    if [ ! -s temp_sequences.fasta ]; then
        echo "WARNING: No FASTA sequences found in response, creating empty file"
        touch ${meta.pdb_id}_seq_1.fasta
    else
        echo "Successfully extracted FASTA sequences"
        total_seqs=\$(grep -c '^>' temp_sequences.fasta || echo 0)
        echo "Number of sequences: \$total_seqs"

        # Split multi-FASTA into individual files
        seq_counter=1
        current_seq=""
        current_header=""

        while IFS= read -r line; do
            if [[ "\$line" == ">"* ]]; then
                # If we have a previous sequence, write it to file
                if [ ! -z "\$current_header" ]; then
                    echo "\$current_header" > ${meta.pdb_id}_seq_\${seq_counter}.fasta
                    echo "\$current_seq" >> ${meta.pdb_id}_seq_\${seq_counter}.fasta
                    echo "Created ${meta.pdb_id}_seq_\${seq_counter}.fasta"
                    seq_counter=\$((seq_counter + 1))
                fi
                # Start new sequence
                current_header="\$line"
                current_seq=""
            else
                # Append to current sequence
                if [ ! -z "\$current_seq" ]; then
                    current_seq="\$current_seq\$line"
                else
                    current_seq="\$line"
                fi
            fi
        done < temp_sequences.fasta

        # Write the last sequence
        if [ ! -z "\$current_header" ]; then
            echo "\$current_header" > ${meta.pdb_id}_seq_\${seq_counter}.fasta
            echo "\$current_seq" >> ${meta.pdb_id}_seq_\${seq_counter}.fasta
            echo "Created ${meta.pdb_id}_seq_\${seq_counter}.fasta"
        fi

        # Clean up temp file
        rm temp_sequences.fasta

        echo "Split \$total_seqs sequences into individual FASTA files"
    fi

    echo "Completed ProteinMPNN processing for ${meta.pdb_id}"
    """
}

