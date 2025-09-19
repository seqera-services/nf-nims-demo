process BOLTZ2_SCRIPT {
    tag "${meta.pdb_id}"
    executor 'local'

    publishDir "${params.output_dir}/boltz2_outputs", mode: 'copy'

    input:
    tuple val(meta), val(fasta_content), path(pdb_file)

    output:
    tuple val(meta), path("design_${meta.design_number}_boltz2_output.json"), path("design_${meta.design_number}_boltz2.multimer.cif"), emit: predicted_structures

    script:
    """
    set -e

    echo "Processing ${meta.pdb_id} with Boltz2"

    # Check API key
    if [ -z "\$NVCF_RUN_KEY" ]; then
        echo "ERROR: NVCF_RUN_KEY environment variable is not set"
        exit 1
    fi

    # Constants
    PUBLIC_URL="https://health.api.nvidia.com/v1/biology/mit/boltz2/predict"
    NVCF_POLL_SECONDS=300
    MANUAL_TIMEOUT_SECONDS=400

    echo "Extracting sequences for complex prediction"
    echo "FASTA content: ${fasta_content}"
    echo "PDB file: ${pdb_file}"

    # Extract ProteinMPNN designed sequence from FASTA content
    proteinmpnn_raw=\$(echo "${fasta_content}" | grep -v '^>' | tr -d '\\n')
    # Clean sequence - only keep valid amino acids for Boltz2 (remove B, O, J, U, Z and other invalid chars)
    proteinmpnn_sequence=\$(echo "\$proteinmpnn_raw" | sed 's/[^ACDEFGHIKLMNPQRSTVWXY]//g')

    # Truncate ProteinMPNN sequence if too long for Boltz2 (4096 char limit)
    if [ \${#proteinmpnn_sequence} -gt 4000 ]; then
        echo "WARNING: ProteinMPNN sequence too long (\${#proteinmpnn_sequence} chars), truncating to first 4000 characters"
        proteinmpnn_sequence=\${proteinmpnn_sequence:0:4000}
    fi

    echo "ProteinMPNN sequence: \${proteinmpnn_sequence:0:20}...\${proteinmpnn_sequence: -10}"
    echo "ProteinMPNN length: \${#proteinmpnn_sequence}"

    # Extract original PDB sequence from SEQRES records (contains 3-letter amino acid codes)
    echo "Extracting sequence from SEQRES records..."
    pdb_sequence_3letter=\$(grep '^SEQRES' "${pdb_file}" | awk '{for(i=4;i<=NF;i++) printf "%s", \$i}' | sed 's/[0-9]//g')

    # Convert 3-letter codes to 1-letter codes (skip rare amino acids SEC and PYL that Boltz2 doesn't accept)
    pdb_sequence=\$(echo "\$pdb_sequence_3letter" | sed 's/ALA/A/g; s/ARG/R/g; s/ASN/N/g; s/ASP/D/g; s/CYS/C/g; s/GLU/E/g; s/GLN/Q/g; s/GLY/G/g; s/HIS/H/g; s/ILE/I/g; s/LEU/L/g; s/LYS/K/g; s/MET/M/g; s/PHE/F/g; s/PRO/P/g; s/SER/S/g; s/THR/T/g; s/TRP/W/g; s/TYR/Y/g; s/VAL/V/g; s/SEC//g; s/PYL//g; s/UNK//g' | sed 's/[^ACDEFGHIKLMNPQRSTVWXY]//g')

    # If SEQRES not available, show warning (most PDB files should have SEQRES)
    if [ -z "\$pdb_sequence" ]; then
        echo "WARNING: No SEQRES records found in PDB file!"
        echo "This PDB file may be incomplete or malformed."
        exit 1
    fi

    # Truncate sequence if too long for Boltz2 (4096 char limit)
    if [ \${#pdb_sequence} -gt 4000 ]; then
        echo "WARNING: PDB sequence too long (\${#pdb_sequence} chars), truncating to first 4000 characters"
        pdb_sequence=\${pdb_sequence:0:4000}
    fi

    echo "Original PDB sequence: \${pdb_sequence:0:20}...\${pdb_sequence: -10}"
    echo "PDB length: \${#pdb_sequence}"

    if [ -z "\$proteinmpnn_sequence" ] || [ -z "\$pdb_sequence" ]; then
        echo "ERROR: Could not extract sequences!"
        echo "ProteinMPNN seq empty: \$([ -z "\$proteinmpnn_sequence" ] && echo "yes" || echo "no")"
        echo "PDB seq empty: \$([ -z "\$pdb_sequence" ] && echo "yes" || echo "no")"
        exit 1
    fi

    # Create JSON payload for multimer complex prediction
    data=\$(cat <<EOF
{
    "polymers": [
        {
            "id": "A",
            "molecule_type": "protein",
            "sequence": "\$pdb_sequence",
            "msa": {
                "uniref90": {
                    "a3m": {
                        "alignment": ">original_pdb\\n\$pdb_sequence",
                        "format": "a3m"
                    }
                }
            }
        },
        {
            "id": "B",
            "molecule_type": "protein",
            "sequence": "\$proteinmpnn_sequence",
            "msa": {
                "uniref90": {
                    "a3m": {
                        "alignment": ">proteinmpnn_design\\n\$proteinmpnn_sequence",
                        "format": "a3m"
                    }
                }
            }
        }
    ],
    "recycling_steps": ${params.boltz2_recycling_steps ?: 1},
    "sampling_steps": ${params.boltz2_sampling_steps ?: 50},
    "diffusion_samples": ${params.boltz2_diffusion_samples ?: 3},
    "step_scale": ${params.boltz2_step_scale ?: 1.2},
    "without_potentials": ${params.boltz2_without_potentials ?: true}
}
EOF
)

    echo "Request payload preview: \$(echo \"\$data\" | head -c 200)..."

    # Create temporary files for response
    response_headers=\$(mktemp)
    response_body=\$(mktemp)

    echo "Making Boltz2 API call..."
    # Perform the POST request
    curl_exit_code=0
    curl -s -D "\$response_headers" -o "\$response_body" -X POST "\$PUBLIC_URL" \\
        -H "Authorization: Bearer \$NVCF_RUN_KEY" \\
        -H "NVCF-POLL-SECONDS: \$NVCF_POLL_SECONDS" \\
        -H "Content-Type: application/json" \\
        --max-time "\$MANUAL_TIMEOUT_SECONDS" \\
        -d "\$data" || curl_exit_code=\$?

    # Extract status code
    status_code=\$(grep -i "^HTTP/" "\$response_headers" | tail -n1 | awk '{print \$2}')
    echo "Received HTTP status code: \$status_code"

    # Save the response
    cp "\$response_body" design_${meta.design_number}_boltz2_output.json

    if [ "\$status_code" -eq 200 ]; then
        echo "SUCCESS: Request succeeded - processing response"

        # Extract mmCIF structure from response
        jq -r '.structures[0].structure // empty' design_${meta.design_number}_boltz2_output.json > design_${meta.design_number}_boltz2.multimer.cif

        # Check if structure was extracted
        if [ ! -s design_${meta.design_number}_boltz2.multimer.cif ]; then
            echo "WARNING: No structure found in response, creating placeholder"
            echo "# No structure returned from Boltz2" > design_${meta.design_number}_boltz2.multimer.cif
        else
            echo "Successfully extracted predicted structure (mmCIF format)"
            echo "Structure file size: \$(wc -c < design_${meta.design_number}_boltz2.multimer.cif) bytes"
            echo "Structure format: mmCIF"
        fi
            
        # Extract and log analysis info
        num_structures=\$(jq '.structures | length' design_${meta.design_number}_boltz2_output.json 2>/dev/null || echo "0")
        num_scores=\$(jq '.confidence_scores | length' design_${meta.design_number}_boltz2_output.json 2>/dev/null || echo "0")
        echo "Number of structures returned: \$num_structures"
        echo "Number of confidence scores: \$num_scores"

    elif [ "\$status_code" -eq 202 ]; then
        echo "INFO: Request accepted - task queued for processing"

        # Extract Task ID for potential polling (not implemented yet)
        task_id=\$(grep -i "nvcf-reqid:" "\$response_headers" | awk '{print \$2}' | tr -d '\\r\\n')
        echo "Task ID: \$task_id"

        # Create placeholder mmCIF file for queued tasks
        echo "# Task queued with ID: \$task_id" > design_${meta.design_number}_boltz2.multimer.cif

    elif [ "\$status_code" -eq 429 ]; then
        echo "WARNING: Rate limited (HTTP 429) - will retry via Nextflow retry mechanism"
        echo "Response: \$(cat "\$response_body")"

        # Create placeholder and exit with error to trigger retry
        echo "# Rate limited - retrying" > design_${meta.design_number}_boltz2.multimer.cif
        exit 1

    else
        echo "ERROR: Request failed with status code: \$status_code"
        echo "Response body:"
        cat "\$response_body"

        # Create error placeholder
        echo "# Error: HTTP \$status_code" > design_${meta.design_number}_boltz2.multimer.cif
        exit 1
    fi

    # Cleanup temporary files
    rm -f "\$response_headers" "\$response_body"

    echo "Completed Boltz2 processing for design_${meta.design_number}"
    """
}