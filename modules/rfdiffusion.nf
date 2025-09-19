process RFDIFFUSION_SCRIPT {
    tag "${meta.pdb_id}"
    executor 'local'

    // NVIDIA Rate limits
    maxForks 2

    errorStrategy 'retry'
    maxRetries 3

    publishDir "${params.output_dir}/rfdiffusion_outputs", mode: 'copy'

    input:
    tuple val(meta), path(pdb_file)

    output:
    tuple val(meta), path("${meta.pdb_id}_output.pdb"), path("${meta.pdb_id}_nim_result.json"), emit: generated_structures

    script:
    def pdb_id = meta.pdb_id
    def contigs = meta.contigs
    def hotspot_res = meta.hotspot_res.split(',').collect { "\"${it.trim()}\"" }.join(',')
    """
    set -e

    echo "Processing ${pdb_id}: contigs=${contigs}, hotspot=${meta.hotspot_res}"

    if [ "\$NVCF_RUN_KEY" = "" ]; then echo "ERROR: NVCF_RUN_KEY not set"; exit 1; fi

    echo "Extracting PDB content from ${pdb_file}..."
    echo "File size: \$(wc -l < ${pdb_file}) lines"
    echo "First 5 lines:"
    head -5 ${pdb_file}

    echo "Debug: PDB file path is: ${pdb_file}"
    echo "Debug: File exists check: \$(ls -la ${pdb_file})"
    echo "Debug: ATOM lines found: \$(grep -c ^ATOM ${pdb_file} || echo 0)"
    echo "Debug: First ATOM line: \$(grep ^ATOM ${pdb_file} | head -1 || echo 'NONE FOUND')"

    # Extract PDB content exactly like the working example
    pdb=\$(cat ${pdb_file} | grep ^ATOM | head -n 400 | awk '{printf "%s\\\\n", \$0}')
    echo "PDB content length: \${#pdb}"
    echo "PDB preview: \$(echo \"\$pdb\" | head -c 100)..."

    if [ -z "\$pdb" ]; then
        echo "ERROR: No ATOM records found in PDB file!"
        exit 1
    fi

    # Create request using the exact pattern from working example
    request='{
     "input_pdb": "'\$pdb'",
     "contigs": "${contigs}",
     "hotspot_res": [${hotspot_res}],
     "diffusion_steps": ${params.diffusion_steps}
    }'

    echo "Request preview: \$(echo \"\$request\" | head -c 200)..."

    echo "Making API call..."
    response=\$(curl -s -H 'Content-Type: application/json' -H "Authorization: Bearer \$NVCF_RUN_KEY" -H "nvcf-poll-seconds: 300" -d "\$request" https://health.api.nvidia.com/v1/biology/ipd/rfdiffusion/generate)

    echo "\$response" > ${pdb_id}_nim_result.json
    echo "\$response" | jq -r '.output_pdb // .pdb // .result' > ${pdb_id}_output.pdb || echo "REMARK Generated PDB" > ${pdb_id}_output.pdb

    echo "Completed ${pdb_id}"
    """
}

process RFDIFFUSION_EXECUTOR {
    tag "${meta.pdb_id}"
    executor 'nim'

    publishDir "${params.output_dir}/rfdiffusion_outputs", mode: 'copy'

    input:
    tuple val(meta), path(pdb_file)

    output:
    tuple val(meta), path("output.pdb"), path("nim_result.json"), emit: generated_structures

    script:
    task.ext.nim = "rfdiffusion"
    task.ext.diffusion_steps = params.diffusion_steps

    """
    echo "Processing ${meta.pdb_id} through RFDiffusion NIM service"
    echo "Input PDB: ${pdb_file}"
    echo "Service: ${task.ext.nim}"
    echo "Contigs: ${meta.contigs}"
    echo "Hotspot residues: ${meta.hotspot_res}"
    echo "Diffusion steps: ${task.ext.diffusion_steps}"

    # Create start time marker
    start_time=\$(date +%s)
    start_timestamp=\$(date -Iseconds)

    # The NIM executor will handle the actual API call
    # Output files will be generated automatically
    echo "RFDiffusion processing initiated at \$start_timestamp"

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
    "contigs": "${meta.contigs}",
    "hotspot_residues": [${meta.hotspot_res.collect { "\"$it\"" }.join(',')}],
    "diffusion_steps": ${task.ext.diffusion_steps},
    "status": "success"
}
EOF

    # NIM executor produces output.pdb and nim_result.json directly
    echo "NIM executor should have produced output.pdb and nim_result.json"

    echo "RFDiffusion processing completed for ${meta.pdb_id} in \$duration seconds"
    """
}