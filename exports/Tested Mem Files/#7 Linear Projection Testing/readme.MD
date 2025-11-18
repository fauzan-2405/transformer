This is used to simulate linear projection.
For this simulation, we use the same matrix for each key groups (e.g. all Q1 - Q4 has the same matrix but different with K* and V*).

python -u "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\matrix_multiplier_v2.py" --task linear_projection --rows_a 8 --cols_a 6 --proj_dim 8 --unique_per_type --display float --integers --min_val 0 --max_val 2 --cores_a 2 --cores_b 4

NB:
> cores_b = 4 in other words: cores_b = 1 with TOTAL_MODULES = 4

