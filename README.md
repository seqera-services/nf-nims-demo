# NF-NIMS Demo - Running NVIDIA NIMs with Nextflow

Complete protein binder design pipeline using NVIDIA NIM services: RFDiffusion for binder structure generation, ProteinMPNN for sequence optimization, and Boltz2 for structure prediction.

## Quick Start

```bash
# Set your NVIDIA NIM API key
export NVCF_RUN_KEY="your-nim-api-key"

# Test with single structure (recommended first run)
nextflow run main.nf -profile test
```

## Pipeline Overview

1. **Downloads** protein structures from PDB
2. **Generates** novel structures with RFDiffusion
3. **Optimizes** sequences using ProteinMPNN
4. **Predicts** final structures with Boltz2
5. **Reports** success rates and processing times

## Test Profile Configuration

The `-profile test` uses a single validated structure (PDB: 1R42, ACE2) with the following parameters:

- **Contigs**: `A20-60/0 50-100` - Design segments and lengths
- **Hotspots**: `A50,A51,A52,A53,A54` - Key residues for design
- **Diffusion Steps**: `15` - RFDiffusion sampling steps
- **ProteinMPNN**: 5 sequences per design at 0.1 temperature
- **Boltz2**: 3 samples with 50 sampling steps

## Run Commands

```bash
# Quick test (single structure)
nextflow run main.nf -profile test

# Custom parameters
nextflow run main.nf \
  --input your_dataset.csv \
  --diffusion_steps 20 \
  --output_dir custom_results
```

## Input Format

CSV file with columns:
- `pdb_id`: PDB structure identifier
- `name`: Descriptive name
- `contigs`: Design constraints
- `hotspot_res`: Key residues
- `proteinmpnn_*`: ProteinMPNN parameters

## Output Structure

```
results/
├── rfdiffusion/           # Generated backbone structures
├── proteinmpnn/           # Optimized sequences
├── boltz2/                # Final structure predictions
├── execution_report.html  # Processing summary
└── execution_timeline.html # Performance timeline
```

## Requirements

- Nextflow ≥25.04.0
- nf-nim plugin @0.3.0
- NVIDIA NIM API access (RFDiffusion, ProteinMPNN, Boltz2)

## Configuration

The workflow automatically:
- ✅ Downloads PDB files from RCSB
- ✅ Rate limits API calls (maxForks: 1-2 per service)
- ✅ Retries failed requests (3x with 30s delay)
- ✅ Generates comprehensive execution reports