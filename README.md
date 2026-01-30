# Nextflow Pipeline for Running and Evaluating Multiple moDiNA Configurations

This pipeline enables running multiple moDiNA configurations in an reproducible and scalable environment and evaluating configurations using different schemes. 

# Preparation

To start, clone the repository:

```{bash}
git clone https://github.com/DyHealthNet/modina_nf_pipeline.git
```

## Installations

Execution of the pipeline requires the installation of Java and Nextflow. Depending on the compute environment you select, either Conda, Docker or Singularity have to be installed.

Details on how to install Java and Nextflow can be found here: https://www.nextflow.io/docs/latest/install.html.

## Prepare Your Data

In order to run the pipeline on simulated data or your own data, please fill out the ``nextflow.config`` file.

# Run Nextflow Pipeline

Once all parameters have been correctly specified, the pipeline can be executed.

We support execution through Conda (-profile conda) and enable job scheduling via SLURM (e.g., -profile slurm,conda).


```bash
nextflow run main.nf -profile slurm,conda
```

To resume the workflow:

```bash
nextflow run main.nf -profile slurm,docker -resume
```

