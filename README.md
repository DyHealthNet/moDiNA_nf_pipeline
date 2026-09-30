# Nextflow Pipeline for Running and Evaluating Multiple moDiNA Configurations

This pipeline enables running multiple moDiNA configurations in an reproducible and scalable environment and evaluating configurations using different schemes. 

If you want to use the Python package, please refer to this [repository](https://github.com/DyHealthNet/moDiNA).

A detailed documentation of the individual steps is provided at our readthedocs website: [https://dyhealthnet.github.io/moDiNA/index.html](https://dyhealthnet.github.io/moDiNA/).

## Installation 

> If you are new to Nextflow, please refer to this page: https://nf-co.re/docs/usage/installation

Then clone the moDiNA Nextflow pipeline repository:

```bash
git clone https://github.com/DyHealthNet/moDiNA_nf_pipeline.git
```

TODO: create conda environments if this is not working automatically...

## Parameters 

The Nextflow pipeline is designed to run multiple configurations in parallel, allowing users to systematically evaluate different settings and their impact on the results. 
To specify the configurations, you can either change the parameters in the nextflow.config file or create a configuration file (e.g., params.yml).

### General Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| name_context_1 | string | context1 | Label assigned to the first context (e.g. Female or Control). |
| name_context_2 | string | context2 | Label assigned to the second context (e.g. Male or Disease). |
| run_type | string | file | Determines how moDiNA configurations are specified. One of single (one fixed configuration), all (all valid combinations), or file (read from a CSV samplesheet). |
| data_type | string | simulation | Source of input data. Either simulation (generate synthetic data via copula) or real (provide real-world data files). |
| out_dir | path | '' | Absolute path to the directory where all pipeline outputs are written. |
| work_dir | path | '' | Absolute path to the work directory of the Nextflow pipeline. |
| out_dir | boolean | true | Boolean specifying whether evaluation plots should be generated. |


### Environment Parameters

| Parameter | Type | Description |
|---|---|---|
| conda_modina_env | path | Absolute path to the conda environment used for all core moDiNA processes (network inference, ranking, …). |
| conda_eval_env | path | Absolute path to the conda environment used for R-based evaluation process. |

### Simulation Parameters (simulation.*)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `simulation.n_simulations` | `integer` | `3` | Number of independent simulation replicates to run. |
| `simulation.n_bi` | `integer` | `50` | Number of binary nodes to simulate. |
| `simulation.n_cont` | `integer` | `50` | Number of continuous nodes to simulate. |
| `simulation.n_cat` | `integer` | `50` | Number of categorical nodes to simulate. |
| `simulation.n_samples_1` | `integer` | `500` | Number of samples (observations) for the first context. |
| `simulation.n_samples_2` | `integer` | `500` | Number of samples (observations) for the second context. |
| `simulation.n_shift_cont` | `integer` | `4` | Number of continuous nodes with an artificially introduced mean shift between contexts. |
| `simulation.n_shift_bi` | `integer` | `4` | Number of binary nodes with an artificially introduced mean shift between contexts. |
| `simulation.n_shift_cat` | `integer` | `4` | Number of categorical nodes with an artificially introduced mean shift between contexts. |
| `simulation.n_corr_cont_cont` | `integer` | `2` | Number of continuous–continuous node pairs with an artificially introduced correlation difference between contexts. |
| `simulation.n_corr_bi_bi` | `integer` | `2` | Number of binary–binary node pairs with an artificially introduced correlation difference between contexts. |
| `simulation.n_corr_cat_cat` | `integer` | `2` | Number of categorical–categorical node pairs with an artificially introduced correlation difference between contexts. |
| `simulation.n_corr_bi_cont` | `integer` | `2` | Number of binary–continuous node pairs with an artificially introduced correlation difference between contexts. |
| `simulation.n_corr_bi_cat` | `integer` | `2` | Number of binary–categorical node pairs with an artificially introduced correlation difference between contexts. |
| `simulation.n_corr_cont_cat` | `integer` | `2` | Number of continuous–categorical node pairs with an artificially introduced correlation difference between contexts. |
| `simulation.n_both_cont_cont` | `integer` | `2` | Number of continuous–continuous node pairs with both a mean shift and a correlation difference. |
| `simulation.n_both_bi_bi` | `integer` | `2` | Number of binary–binary node pairs with both a mean shift and a correlation difference. |
| `simulation.n_both_cat_cat` | `integer` | `2` | Number of categorical–categorical node pairs with both a mean shift and a correlation difference. |
| `simulation.n_both_bi_cont` | `integer` | `2` | Number of binary–continuous node pairs with both a mean shift and a correlation difference. |
| `simulation.n_both_bi_cat` | `integer` | `2` | Number of binary–categorical node pairs with both a mean shift and a correlation difference. |
| `simulation.n_both_cont_cat` | `integer` | `2` | Number of continuous–categorical node pairs with both a mean shift and a correlation difference. |
| `simulation.corr_low` | `float` | `0.1` | Lower end of the range each correlation difference is drawn from. Must satisfy `0 ≤ corr_low ≤ corr_high ≤ 0.95`. |
| `simulation.corr_high` | `float` | `0.7` | Upper end of that range. Set equal to `corr_low` for a single fixed magnitude. |
| `simulation.shift_low` | `float` | `0.2` | Lower end of the range each mean shift is drawn from. Must satisfy `0 ≤ shift_low ≤ shift_high`. |
| `simulation.shift_high` | `float` | `0.8` | Upper end of that range. Set equal to `shift_low` for a single fixed magnitude. |
| `simulation.hub_reuse_prob` | `float` | `0.5` | Probability that a new correlation/both pair reuses an already-placed node as a hub instead of drawing two fresh nodes. `0.0` gives one edge per node. Must be in [0, 1]. |
| `simulation.background_topology` | `string` | `null` | Wiring of the shared background correlation structure: `scale_free`, `erdos_renyi`, or `none`/`null` to disable it (every non-ground-truth pair exactly independent). |
| `simulation.background_strength` | `float` | `0.2` | Target mean \|r\| over the directly wired pairs of the background. Must be strictly between 0 and 1. Ignored when the background is off. |
| `simulation.background_density` | `integer` | `2` | Connections each node makes when it is added to the background network. Must be ≥ 1 and < the total number of variables. Ignored when the background is off. |
| `simulation.background_seed` | `integer` | `null` | Base seed for the background's own random generator, offset by the replicate id so each replicate draws its own background reproducibly. Leave unset for a fresh, non-reproducible background per replicate. |
| `simulation.binary_p_low` | `float` | `0.3` | Lower end of the range binary base rates are drawn from. Rates far from 0.5 cap the attainable φ-coefficient and attenuate any edge touching the node. |
| `simulation.binary_p_high` | `float` | `0.7` | Upper end of that range. |
| `simulation.ordinal_concentration` | `float` | `20.0` | Symmetric Dirichlet concentration for categorical category probabilities. Larger values keep categories closer to balanced; small values leave categories nearly empty and attenuate edges. |

> **Migration note.** `simulation.shift` and `simulation.corr` were replaced by the four `*_low`/`*_high`
> parameters above. Each ground truth effect now draws its own magnitude uniformly from the given
> range, and the drawn value is recorded per node/edge in the ground truth files (`shift` and
> `corr` columns), so a single run can be binned by realized effect size rather
> than producing one operating point. To reproduce a previous run exactly, set
> `corr_low: corr_high: <old corr>` and `shift_low: shift_high: <old shift>`. Params files still
> carrying the old keys fail validation with an explicit message rather than silently ignoring them.
>
> Note that `background_strength` and `corr_high` compete for the same positive-definiteness budget:
> a stronger background lowers the smallest eigenvalue of `Σ_base`, below which `corr_high` must stay,
> and a hub reused across several edges spends the sum of their squared magnitudes against it. Raise
> the two together only after checking that a simulation still runs.

### Real-World Data Parameters (`real_world_data.*`)

Only required when `data_type = 'real'`.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `real_world_data.path_context_1` | `path` | `''` | Absolute path to the CSV data file for context 1 (rows: samples, columns: variables). |
| `real_world_data.path_context_2` | `path` | `''` | Absolute path to the CSV data file for context 2 (rows: samples, columns: variables). |
| `real_world_data.path_meta` | `path` | `''` | Absolute path to the metadata CSV file containing variable labels and data types. |

### Differential Network Analysis Parameters (`diff_net_analysis.*`)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `diff_net_analysis.path_config` | `path` | `'input_samplesheet.csv'` | Path to the CSV samplesheet listing moDiNA configurations to run. Required when `run_type = 'file'`. Columns: `node_metric`, `edge_metric`, `ranking_algorithm`. |
| `diff_net_analysis.node_metric` | `string` | `'STC'` | Node-level differential metric. Used when `run_type = 'single'`. One of: `STC`, `DC-P`, `DC-E`, `WDC-P`, `WDC-L-P`, `WDC-E`, `PRC-P`, `PRC-L-P`, `PRC-E`, `None`. |
| `diff_net_analysis.edge_metric` | `string` | `'diff-E'` | Edge-level differential metric. Used when `run_type = 'single'`. One of: `diff-P`, `diff-E`, `diff-L-P` (difference of -log10(p-values) between contexts), `diff-L-PE` (difference of -log10(p) × rescaled effect size), `sum-diff-PE`, `sum-diff-L-PE`, `None`. |
| `diff_net_analysis.ranking_algorithm` | `string` | `'PageRank+'` | Algorithm used to rank nodes in the differential network. Used when `run_type = 'single'`. One of: `PageRank+`, `PageRank`, `absDimontRank`, `DimontRank`, `nodeRank`. |
| `diff_net_analysis.filter_target` | `string` | `''` | Which network to filter. Leave empty to skip filtering. `context-specific` filters the two context networks before differential analysis (using `filter_metric` and `filter_rule`); `differential` filters the differential network on the computed `edge_metric` (`filter_metric` and `filter_rule` are ignored). When set, `filter_method` is required. |
| `diff_net_analysis.filter_method` | `string` | `''` | Method to filter edges. One of: `degree`, `density`, `quantile`. Required when `filter_target` is set. |
| `diff_net_analysis.filter_param` | `integer / float` | `2` | Parameter for the chosen filter method. Integer for `degree`; float in (0, 1) for `density` and `quantile`. |
| `diff_net_analysis.filter_metric` | `string` | `'raw-P'` | Edge score used as the basis for filtering. One of: `raw-P`, `rescaled-E`. Required when `filter_method` is set and `filter_target` is `context-specific`. |
| `diff_net_analysis.filter_rule` | `string` | `'zero'` | Rule applied when filtering edges. One of: `zero` (set filtered edges to zero), `union` (keep edges present in at least one context). Required when `filter_method` is set and `filter_target` is `context-specific`. |
| `diff_net_analysis.max_path_length` | `integer` | `2` | Maximum path length used for the `int-IS` edge metric. Must be an integer in [0, 4]. Only relevant when `int-IS` is selected as an edge metric. |
| `diff_net_analysis.test_type` | `string` | `'nonparametric'` | Type of statistical test used during context network inference. One of: `parametric`, `nonparametric`. |
| `diff_net_analysis.nan_value` | `integer` | `-89` | Sentinel value in input data that represents missing / NA values. |
| `diff_net_analysis.multiple_testing` | `string` | `'bh'` | Multiple testing correction method applied to association p-values. One of: `bh` (Benjamini–Hochberg), `by` (Benjamini–Yekutieli). |


## Usage 

You can choose between the following profiles: conda, docker, singularity, slurm. The respective profile will be used to execute the pipeline with the appropriate containerization or job scheduling system. You can specify the profile using the -profile flag when running the Nextflow pipeline. For example, to run the pipeline using conda for package management and SLURM for distributed execution, you would use the following command:

Now, you can run the Nextflow pipeline using the following command:

```bash
nextflow run main.nf -profile conda,slurm
```

If you have stored the parameters in a params.yml file instead of the nextflow.config file, you can specify the path to this file using the -params-file flag:

```bash
nextflow run main.nf -profile conda,slurm -params-file path/to/your/params.yml
```

## Pipeline Output

The results are stored in the specified output directory, which is organized by differential network analysis steps and evaluation steps.

The main output of the pipeline includes: - Simulated datasets for each simulation replicate (if data_type = 'simulation'). - Inferred context-specific networks for each context and simulation. - Node and edge metrics files for each configuration and simulation. - Ranking results for each configuration and simulation. - Evaluation results

# Citation

TODO
