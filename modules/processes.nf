

// process collectMetrics {
//     publishDir "${params.output_dir}/analysis", mode: 'copy'

//     input:
//     path metrics_files

//     output:
//     path "batch_metrics.json"
//     path "processing_summary.txt"

//     script:
//     """
//     # Combine all individual metrics into a single JSON array
//     echo "[" > batch_metrics.json
//     first=true
//     for metrics_file in ${metrics_files}; do
//         if [[ "\$first" == "true" ]]; then
//             first=false
//         else
//             echo "," >> batch_metrics.json
//         fi
//         cat "\$metrics_file" >> batch_metrics.json
//     done
//     echo "]" >> batch_metrics.json

//     # Generate processing summary
//     total_structures=\$(echo '${metrics_files}' | wc -w)
//     successful_structures=\$(grep -c '"status": "success"' batch_metrics.json)
//     failed_structures=\$((total_structures - successful_structures))

//     # Calculate timing statistics
//     min_duration=\$(jq -r '.[].duration_seconds' batch_metrics.json | sort -n | head -1)
//     max_duration=\$(jq -r '.[].duration_seconds' batch_metrics.json | sort -n | tail -1)
//     avg_duration=\$(jq -r '[.[].duration_seconds] | add / length' batch_metrics.json)
//     total_duration=\$(jq -r '[.[].duration_seconds] | add' batch_metrics.json)

//     cat > processing_summary.txt << EOF
// BATCH NIMS PROCESSING SUMMARY
// =============================
// Total Structures Processed: \$total_structures
// Successful Processes: \$successful_structures
// Failed Processes: \$failed_structures
// Success Rate: \$(echo "scale=2; \$successful_structures * 100 / \$total_structures" | bc -l)%

// TIMING STATISTICS
// =================
// Minimum Processing Time: \$min_duration seconds
// Maximum Processing Time: \$max_duration seconds
// Average Processing Time: \$(echo "scale=2; \$avg_duration" | bc -l) seconds
// Total Processing Time: \$total_duration seconds

// PARAMETERS USED
// ===============
// Contigs: ${params.contigs}
// Hotspot Residues: ${params.hotspot_res}
// Diffusion Steps: ${params.diffusion_steps}
// Max Retries: ${params.max_retries}
// EOF

//     echo "Metrics collection completed"
//     echo "Total structures processed: \$total_structures"
//     echo "Success rate: \$(echo "scale=1; \$successful_structures * 100 / \$total_structures" | bc -l)%"
//     """
// }

// process generateSummaryReport {
//     publishDir "${params.output_dir}/reports", mode: 'copy'

//     input:
//     path metrics_file
//     path result_files

//     output:
//     path "batch_processing_report.html"
//     path "structure_analysis.json"

//     script:
//     """
//     # Count successful outputs
//     successful_pdbs=\$(ls -1 *_output.pdb 2>/dev/null | wc -l)
//     successful_results=\$(ls -1 *_nim_result.json 2>/dev/null | wc -l)

//     # Extract key statistics from metrics
//     total_time=\$(jq -r '[.[].duration_seconds] | add' ${metrics_file})
//     avg_time=\$(jq -r '[.[].duration_seconds] | add / length' ${metrics_file})
//     max_time=\$(jq -r '[.[].duration_seconds] | max' ${metrics_file})
//     min_time=\$(jq -r '[.[].duration_seconds] | min' ${metrics_file})

//     # Generate structure analysis
//     cat > structure_analysis.json << EOF
// {
//     "summary": {
//         "total_structures_attempted": \$(jq length ${metrics_file}),
//         "successful_structures": \$successful_pdbs,
//         "generated_pdb_files": \$successful_pdbs,
//         "generated_result_files": \$successful_results,
//         "total_processing_time_seconds": \$total_time,
//         "average_processing_time_seconds": \$avg_time,
//         "max_processing_time_seconds": \$max_time,
//         "min_processing_time_seconds": \$min_time
//     },
//     "parameters": {
//         "contigs": "${params.contigs}",
//         "hotspot_residues": [${params.hotspot_res.collect { "\"$it\"" }.join(',')}],
//         "diffusion_steps": ${params.diffusion_steps},
//         "max_retries": ${params.max_retries}
//     },
//     "workflow_info": {
//         "workflow_name": "Batch NIMS Processing",
//         "execution_date": "\$(date -Iseconds)",
//         "output_directory": "${params.output_dir}"
//     }
// }
// EOF

//     # Generate HTML report with a simple template
//     cat > batch_processing_report.html << 'HTML_EOF'
// <!DOCTYPE html>
// <html>
// <head>
//     <title>Batch NIMS Processing Report</title>
//     <style>
//         body { font-family: Arial, sans-serif; margin: 40px; }
//         .header { background-color: #f0f8ff; padding: 20px; border-radius: 10px; }
//         .section { margin: 20px 0; }
//         .metric { background-color: #f9f9f9; padding: 10px; margin: 10px 0; border-left: 4px solid #007acc; }
//         .success { color: #28a745; }
//         .warning { color: #ffc107; }
//         .error { color: #dc3545; }
//         table { border-collapse: collapse; width: 100%; }
//         th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
//         th { background-color: #f2f2f2; }
//     </style>
// </head>
// <body>
//     <div class="header">
//         <h1>🧬 Batch NIMS Processing Report</h1>
//         <p>Massively parallel protein structure analysis using NVIDIA NIM RFDiffusion service</p>
// HTML_EOF

//     echo "        <p><strong>Generated:</strong> \$(date)</p>" >> batch_processing_report.html

//     cat >> batch_processing_report.html << 'HTML_EOF'
//     </div>

//     <div class="section">
//         <h2>📊 Processing Summary</h2>
//         <div class="metric">HTML_EOF
//         echo "            <strong>Total Structures Processed:</strong> \$(jq -r '.summary.total_structures_attempted' structure_analysis.json)" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </div>
//         <div class="metric">HTML_EOF
//         echo "            <strong class=\"success\">Successful Structures:</strong> \$(jq -r '.summary.successful_structures' structure_analysis.json)" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </div>
//         <div class="metric">HTML_EOF
//         echo "            <strong>Success Rate:</strong> \$(echo \"scale=1; \$(jq -r '.summary.successful_structures' structure_analysis.json) * 100 / \$(jq -r '.summary.total_structures_attempted' structure_analysis.json)\" | bc -l)%" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </div>
//     </div>

//     <div class="section">
//         <h2>⏱️ Performance Metrics</h2>
//         <div class="metric">HTML_EOF
//         echo "            <strong>Total Processing Time:</strong> \$(jq -r '.summary.total_processing_time_seconds' structure_analysis.json) seconds" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </div>
//         <div class="metric">HTML_EOF
//         echo "            <strong>Average Processing Time:</strong> \$(echo \"scale=2; \$(jq -r '.summary.average_processing_time_seconds' structure_analysis.json)\" | bc -l) seconds per structure" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </div>
//     </div>

//     <div class="section">
//         <h2>🔧 RFDiffusion Parameters</h2>
//         <table>
//             <tr><th>Parameter</th><th>Value</th></tr>HTML_EOF
//             echo "            <tr><td>Contigs</td><td>\$(jq -r '.parameters.contigs' structure_analysis.json)</td></tr>" >> batch_processing_report.html
//             echo "            <tr><td>Hotspot Residues</td><td>\$(jq -r '.parameters.hotspot_residues | join(\", \")' structure_analysis.json)</td></tr>" >> batch_processing_report.html
//             echo "            <tr><td>Diffusion Steps</td><td>\$(jq -r '.parameters.diffusion_steps' structure_analysis.json)</td></tr>" >> batch_processing_report.html
//             echo "            <tr><td>Max Retries</td><td>\$(jq -r '.parameters.max_retries' structure_analysis.json)</td></tr>" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </table>
//     </div>

//     <div class="section">
//         <h2>📁 Output Files</h2>HTML_EOF
//         echo "        <p><strong>Generated PDB Files:</strong> \$(jq -r '.summary.generated_pdb_files' structure_analysis.json)</p>" >> batch_processing_report.html
//         echo "        <p><strong>Generated Result Files:</strong> \$(jq -r '.summary.generated_result_files' structure_analysis.json)</p>" >> batch_processing_report.html
//         echo "        <p><strong>Output Directory:</strong> \$(jq -r '.workflow_info.output_directory' structure_analysis.json)</p>" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//     </div>

//     <div class="section">
//         <h2>🎯 Key Insights</h2>
//         <ul>
//             <li>Successfully demonstrated massively parallel protein design using NIMS</li>HTML_EOF
//             echo "            <li>Processed \$(jq -r '.summary.total_structures_attempted' structure_analysis.json) diverse protein structures across multiple categories</li>" >> batch_processing_report.html
//             echo "            <li>Achieved \$(echo \"scale=1; \$(jq -r '.summary.successful_structures' structure_analysis.json) * 100 / \$(jq -r '.summary.total_structures_attempted' structure_analysis.json)\" | bc -l)% success rate with built-in retry logic</li>" >> batch_processing_report.html
//             echo "            <li>Average processing time of \$(echo \"scale=1; \$(jq -r '.summary.average_processing_time_seconds' structure_analysis.json)\" | bc -l) seconds per structure</li>" >> batch_processing_report.html
//     cat >> batch_processing_report.html << 'HTML_EOF'
//         </ul>
//     </div>

//     <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
//         <p>Generated by Nextflow Batch NIMS Processing Workflow | Inspired by <a href="https://blog.latch.bio/p/engineering-plastic-degrading-enzymes">Latch.bio's approach</a></p>
//     </footer>
// </body>
// </html>
// HTML_EOF

//     echo "Summary report generated successfully"
//     """
// }