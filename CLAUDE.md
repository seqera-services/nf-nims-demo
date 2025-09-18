# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nextflow-based bioinformatics workflow for massively parallel protein structure analysis using NVIDIA NIM (NVIDIA Inference Microservices) RFDiffusion service.

## Core Architecture

- **Workflow Engine**: Nextflow DSL2 (requires ≥25.04.0)
- **AI Service**: NVIDIA NIM RFDiffusion plugin (nf-nim@0.2.0)
- **Data Source**: PDB structures downloaded via HTTPS
- **Processing Model**: Massively parallel with API rate limiting

## Essential Commands

### Running the Workflow

```bash
# Quick test (5 structures from validated dataset)
nextflow run main.nf -profile test

# Medium scale (50 structures)
nextflow run main.nf -profile medium

# Full scale processing (200+ structures)
nextflow run main.nf -profile full

# Fast processing with reduced parameters
nextflow run main.nf -profile fast

# Custom parameters
nextflow run main.nf \
  --max_structures 100 \
  --contigs "A30-80/0 60-120" \
  --diffusion_steps 20 \
  --output_dir custom_results
```

### Environment Setup

```bash
# Set NVIDIA NIM API key (required)
export NVCF_RUN_KEY="your-nim-api-key"

# Optional: Plugin development mode
export NXF_PLUGINS_MODE=dev

# Alternative: Use direnv with 1Password integration (.envrc is configured)
direnv allow
```

## Key Configuration Files

- **main.nf**: Primary workflow definition with dual RFDiffusion executors
- **processes.nf**: Process definitions for RFDIFFUSION_SCRIPT and RFDIFFUSION_EXECUTOR
- **nextflow.config**: Workflow parameters, process configuration, plugin declaration
- **assets/schema_input.json**: JSON schema for input validation using nf-schema
- **pdb_dataset.csv**: Full dataset (200+ protein structures)
- **pdb_dataset_valid.csv**: Validated subset (1 structure: 1R42) - used by default
- **.envrc**: 1Password integration for secure API key management

## Important Parameters

### RFDiffusion Parameters (in nextflow.config)
- `contigs`: Sequence constraints (default: "A20-60/0 50-100")
- `hotspot_res`: Key residues for design (default: ["A50", "A51", "A52", "A53", "A54"])
- `diffusion_steps`: AI model steps (default: 15)
- `rfdiffusion_batch_size`: Batch processing size (default: 10)

### Processing Control
- `max_structures`: Limit processing (0 = all)
- `max_retries`: Error retry attempts (default: 3)
- `maxForks 2`: API rate limiting in RFDiffusion process

## Data Architecture

### Input Data Flow
1. CSV parsing → Channel creation
2. PDB download via `file("https://files.rcsb.org/download/${pdb_id}.pdb")`
3. NIM processing → AI-powered protein design
4. Result collection → PDB files + JSON metadata

### Output Structure
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

## Parallel Processing Architecture

The workflow demonstrates advanced parallel processing:
- **Channel Processing**: Splits CSV into parallel streams
- **Rate Limiting**: `maxForks 2` respects NVIDIA API limits
- **Error Resilience**: Built-in retry logic with configurable attempts
- **Dynamic File Handling**: Remote PDB downloads integrated into channels

## Development Patterns

### Testing Strategy
- Use **profile-based execution** rather than traditional unit tests
- `test` profile: 5 structures for quick validation
- `medium` profile: 50 structures for integration testing
- Separate validated dataset (`pdb_dataset_valid.csv`) for reliable testing

### Error Handling
- All processes use `errorStrategy = 'retry'`
- Configurable retry attempts and delays
- Graceful handling of invalid PDB files
- Comprehensive error logging

### Security
- Never commit API keys - use environment variables or 1Password integration
- `.envrc` file configured for secure credential management
- API keys should be set as `NVCF_RUN_KEY`

## Workflow Execution Profiles

Profiles are defined for different scales:
- `test`: Quick validation (5 structures)
- `medium`: Medium batch (50 structures)
- `full`: Complete dataset (200+ structures)
- `fast`: Reduced parameters for speed optimization

## Plugin Dependencies

The workflow requires the nf-nim plugin and nf-schema:
```groovy
plugins {
    id 'nf-nim@0.2.0'
    id 'nf-schema@2.5.1'
}
```

Ensure plugins are available before execution. Use `NXF_PLUGINS_MODE=dev` for development.

## Monitoring and Reporting

The workflow generates comprehensive analytics:
- Real-time progress tracking
- Success/failure rate monitoring
- Processing time analytics
- HTML summary reports with key metrics
- JSON data files for programmatic analysis