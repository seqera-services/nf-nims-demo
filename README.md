# NF-NIMS Demo - Protein Design with NVIDIA RFDiffusion

Generate novel protein designs from PDB structures using NVIDIA NIM RFDiffusion service.

## Quick Start

```bash
# Set your NVIDIA NIM API key
export NVCF_RUN_KEY="your-nim-api-key"

nextflow run .
```

## What It Does

1. **Downloads** protein structures from PDB
2. **Processes** them through NVIDIA RFDiffusion
3. **Generates** novel protein designs
4. **Reports** success rates and processing times

## Input Data

- `pdb_dataset_valid.csv`: 9 validated PDB structures (default)
- `pdb_dataset.csv`: 200+ diverse protein structures

## Key Parameters

```bash
nextflow run main.nf \
  --max_structures 100 \
  --diffusion_steps 15 \
  --output_dir results
```

## Execution Profiles

| Profile | Structures | Purpose |
|---------|------------|---------|
| `test` | 9 | Quick validation |
| `medium` | 50 | Integration testing |
| `full` | 200+ | Production scale |
| `fast` | Variable | Speed-optimized |

## Output Structure

```
results/
├── rfdiffusion_outputs/    # Generated protein designs
├── execution_report.html   # Processing summary
└── execution_timeline.html # Performance timeline
```

## Requirements

- Nextflow ≥25.04.0
- nf-nim plugin @0.1.0
- NVIDIA NIM API access

## Configuration

The workflow automatically:
- ✅ Downloads PDB files from RCSB
- ✅ Retries failed requests (3x)
- ✅ Limits API calls with `maxForks 2`
- ✅ Generates execution reports