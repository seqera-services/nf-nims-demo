# NIMS Demo - Massively Parallel Protein Design

This project demonstrates massively parallel protein structure analysis using NVIDIA NIMS RFDiffusion service, processing 200+ diverse protein structures inspired by [Latch.bio's approach](https://blog.latch.bio/p/engineering-plastic-degrading-enzymes) to computational protein engineering.

## Overview

The workflow processes diverse protein structures from the Protein Data Bank (PDB) through RFDiffusion for protein design, similar to how Latch.bio strings together AI tools for useful molecular design tasks.

## Dataset

The `pdb_dataset.csv` contains 200+ carefully curated protein structures across multiple categories:

- **Enzymes**: Catalase, superoxide dismutase, glucose oxidase, etc.
- **Transport Proteins**: Hemoglobin, myoglobin, transferrin, albumin
- **Signaling Proteins**: Protein kinases, growth hormone, insulin  
- **Structural Proteins**: Immunoglobulins, ferritin
- **Small Proteins**: Ubiquitin, crambin, lysozyme
- **Fluorescent Proteins**: GFP variants

## Workflows

### 1. Single Structure Test (`main.nf`)

Test the basic NIMS functionality with a single structure:

```bash
# Original single test
nextflow run main.nf

# Small batch test (5 structures)
nextflow run main.nf --mode batch --batch_size 5
```

### 2. Massively Parallel Processing (`batch_nims.nf`)

Process the full dataset of 200+ structures:

```bash
# Test run (5 structures)
nextflow run batch_nims.nf -profile test

# Medium batch (50 structures)  
nextflow run batch_nims.nf -profile medium

# Full scale processing (all 200+ structures)
nextflow run batch_nims.nf -profile full

# Fast processing with reduced parameters
nextflow run batch_nims.nf -profile fast
```

### 3. Custom Processing

You can customize parameters:

```bash
nextflow run batch_nims.nf \
  --max_structures 100 \
  --contigs "A30-80/0 60-120" \
  --diffusion_steps 20 \
  --output_dir custom_results
```

## Key Features

### 🔄 Parallel Processing
- Processes multiple PDB structures simultaneously
- Configurable batch sizes to optimize API usage
- Built-in retry logic for failed requests

### 📊 Comprehensive Monitoring
- Real-time progress tracking
- Success/failure rate monitoring  
- Processing time analytics
- Resource usage reporting

### 🔍 Analysis & Reporting
- HTML summary reports with key metrics
- JSON data files for programmatic analysis
- Structure-by-structure processing logs
- Performance benchmarking

### 🛠️ Robust Error Handling
- Automatic retry for transient failures
- Graceful handling of invalid PDB files
- Detailed error logging and reporting

## Output Structure

```
results/
├── downloaded_pdbs/           # Original PDB files
├── rfdiffusion_outputs/       # Generated structures
├── analysis/                  # Metrics and summaries  
├── reports/                   # HTML reports
├── execution_report.html      # Nextflow execution report
├── execution_timeline.html    # Processing timeline
└── execution_trace.txt        # Detailed trace log
```

## Key Outputs

- **Generated PDB Files**: New protein designs for each input structure
- **NIM Result Files**: Raw JSON responses from RFDiffusion service
- **Metrics**: Processing times, success rates, parameter effectiveness
- **Summary Report**: Comprehensive HTML dashboard with insights

## Configuration

The workflow supports multiple execution profiles:

- `test`: Quick test with 5 structures
- `medium`: Medium batch with 50 structures  
- `full`: Complete dataset processing
- `fast`: Reduced parameters for speed

## Requirements

- Nextflow ≥25.04.0
- nf-nim plugin @0.1.0
- NVIDIA NIM API access
- Internet connection for PDB downloads

## Environment Setup

```bash
# Set NIM API key
export NVCF_RUN_KEY="your-nim-api-key"

# Optional: Plugin development mode
export NXF_PLUGINS_MODE=dev
```

## Inspiration

This workflow follows the approach outlined in [Latch.bio's engineering blog](https://blog.latch.bio/p/engineering-plastic-degrading-enzymes), demonstrating how to:

> "string together" multiple AI tools for "useful molecular design tasks" enabling massively parallel computational protein engineering analysis

## Key Insights

1. **Scalability**: Successfully processes hundreds of diverse protein structures
2. **Reliability**: Built-in retry logic ensures robust processing  
3. **Efficiency**: Parallel processing maximizes throughput
4. **Analysis**: Comprehensive reporting enables insights and optimization
5. **Flexibility**: Configurable parameters support various use cases

## Next Steps

- Expand dataset with more protein families
- Add additional NIM services (AlphaFold, ESMFold)
- Implement downstream analysis pipelines
- Optimize parameters based on processing results
- Add comparative analysis between original and designed structures

## Citation

If you use this workflow in your research, please cite:

```
NIMS Demo: Massively Parallel Protein Design Workflow
https://github.com/your-repo/nf-nims-demo
```