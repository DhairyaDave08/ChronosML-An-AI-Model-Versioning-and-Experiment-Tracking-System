

## 🗄️ Chronos_ML — Query Concepts

---

### 1. 📊 Model Performance Leaderboard Using Window Ranking

Every model in the system goes through multiple training runs across multiple versions, each producing its own set of evaluation snapshots. The challenge is that a single model might have dozens of metric records scattered across different versions and snapshots, making it difficult to know at a glance which configuration produced the best outcome. A common SQL pattern for this situation is the use of a Common Table Expression (CTE) combined with the `RANK()` window function.

The `RANK()` function, when used with `PARTITION BY`, assigns a rank within each group independently—here, within each model—based on the ordering criterion, which is the F1 score descending. This isolates the best-ever snapshot per model. A second `RANK()` is then applied across all models globally, producing a cross-portfolio leaderboard. The query filters only completed runs to exclude noise from interrupted or failed experiments, and surfaces the algorithm and version alongside the metric—making the result immediately actionable.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Evaluation_Metric, Training_Run, Model_Version, Model |
| **Key SQL Concepts** | CTE, `RANK() OVER (PARTITION BY ...)`, filtering with `WHERE` on status, multi-level window ranking |

---

### 2. 🔄 Version-over-Version Performance Delta Using LAG

When a model is retrained under a new version, the team expects improvement—but that assumption is rarely verified systematically. Over time, without a structured comparison, regressions in F1 score or spikes in validation loss go unnoticed until a model behaves poorly in production. This query addresses that gap by computing the difference in average performance between consecutive model versions.

The `LAG()` window function is central here. It looks back one row within the same model's ordered version sequence and returns the previous version's metric value. Subtracting that from the current value gives the delta—a positive `f1_delta_vs_prev` means the new version improved, a negative value signals a regression. Because individual runs within a version can vary, the query first aggregates metrics to a per-version average using a CTE before applying the window function, ensuring the comparison is stable and not skewed by any single outlier run.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Training_Run, Evaluation_Metric, Model_Version, Model |
| **Key SQL Concepts** | CTE with `GROUP BY` aggregation, `LAG() OVER (PARTITION BY ... ORDER BY ...)`, delta computation, `ROUND()` for clean output |

---

### 3. 📈 Dataset Volume vs. Model Performance Correlation

One of the foundational hypotheses in machine learning is that larger training datasets tend to produce better-performing models. However, this relationship is not guaranteed—a large but poorly curated dataset may underperform a smaller, cleaner one, and the number of features matters as much as the number of rows. To test this hypothesis empirically using the data already in the system, it is necessary to join dataset structural metadata with the evaluation outcomes of every training run that used that dataset.

The query links Dataset_Version (which holds Num_Rows and Num_Features) to Training_Run through the Dataset_Used bridge table, then joins Evaluation_Metric to retrieve the resulting F1 scores. Crucially, it filters on `Split_Type = 'Train'` to focus only on the portion of data the model actually learned from, excluding validation and test splits which would skew the row count. The result is grouped at the dataset-version and model level, allowing visual analysis of how performance scales with data volume.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Dataset_Used, Dataset_Version, Dataset, Training_Run, Model_Version, Model, Evaluation_Metric |
| **Key SQL Concepts** | Multi-table `JOIN` chain, bridge table traversal, `WHERE` filter on categorical split type, `GROUP BY` with aggregate metrics, ordering by Num_Rows |

---

### 4. 📋 Team Productivity and Contribution Scorecard

In a multi-user ML platform, different team members contribute in different ways—some trigger training runs, others own models, curate datasets, or manage deployments. Without a unified view, it is difficult to understand who the active contributors are, where bottlenecks in the pipeline might be, and how storage consumption is distributed. This query constructs a per-user activity summary by aggregating contributions across five separate tables simultaneously.

The approach uses a series of `LEFT JOIN` operations to ensure every user appears in the result even if they have no activity in a particular area. The `FILTER (WHERE ...)` clause on the `COUNT()` aggregate is a clean PostgreSQL feature that allows conditional counting inline—here used to count only model ownerships, not editor or viewer roles. `COALESCE` handles users with no artifacts, preventing NULL from breaking the storage calculation. The full name is assembled from three name columns using string concatenation, with `COALESCE` again guarding against users without a middle name.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Users, Training_Run, Model_Created, Registers, Model_Artifact, Deploys, Deployment |
| **Key SQL Concepts** | Multi-table `LEFT JOIN`, `COUNT(DISTINCT ...)`, `FILTER (WHERE ...)` conditional aggregation, `COALESCE`, string concatenation, `GROUP BY` on composite user identity |

---

### 5. 📉 Statistical Distribution Benchmarks Across ML Categories

Different categories of machine learning—supervised learning, deep learning, reinforcement learning—have fundamentally different performance characteristics and training behaviours. Comparing raw average F1 scores across categories gives an incomplete picture because it ignores spread. A category with a high average but also a high standard deviation may be unreliable, while one with a lower average but tight consistency may be preferable for production. This query computes a full statistical profile per category-problem-type combination, going beyond simple averages.

The query introduces `STDDEV()` to measure score variance, and `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ...)` to compute the true median F1—which is more robust than the mean when the distribution is skewed by outliers. The combination of `MIN`, `MAX`, `AVG`, `STDDEV`, and median on the same metric provides a five-number-style summary that reveals distribution shape without needing external tools. Results are grouped at the intersection of Category and Problem_Type, giving granular but structured insight.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Training_Run, Evaluation_Metric, Model_Version, Model |
| **Key SQL Concepts** | `STDDEV()`, `PERCENTILE_CONT(0.5) WITHIN GROUP`, `MIN`/`MAX`/`AVG` in combination, `GROUP BY` on multiple categorical columns, ordered aggregation |

---

### 6. 🔀 Deployment A/B Comparison Using Self-Join

When a new model version is deployed alongside an existing one for comparison, the Deployment table records this relationship through the Compared_With foreign key, which points from the challenger deployment back to the baseline it is being tested against. Manually querying two separate rows and computing differences is impractical at scale. This query automates the comparison by joining the Deployment table to itself, treating one alias as the challenger and the other as the baseline, and computing metric deltas in a single result set.

The self-join is performed on the condition `baseline.Deployment_ID = challenger.Compared_With`, which resolves the foreign key relationship into a side-by-side row. A CTE first computes the average metrics per deployment by joining back to Training_Run and Evaluation_Metric, ensuring the comparison is based on real measured outcomes rather than stored estimates. A `CASE` expression then classifies each comparison as challenger wins, baseline wins, or no significant difference, using a 0.02 F1 threshold—small enough to be meaningful, large enough to filter statistical noise.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Deployment, Training_Run, Evaluation_Metric, Model |
| **Key SQL Concepts** | CTE for pre-aggregation, self-join on foreign key, metric delta computation, `CASE` expression for categorical verdict, `ORDER BY ABS(...)` for ranking by magnitude |

---

### 7. 📆 Monthly Training Activity Trend Analysis

Understanding how training activity evolves over time reveals patterns in team velocity, infrastructure reliability, and operational risk. A month with a sudden drop in completed runs combined with a rise in failures may indicate a configuration incident or a problematic dataset batch. This query aggregates all training runs by calendar month and computes a breakdown of run outcomes alongside a derived success rate percentage.

The `TO_CHAR(timestamp, 'YYYY-MM')` function normalises timestamps to month granularity, forming the grouping key. The `FILTER (WHERE ...)` aggregate pattern is used four times in a single `SELECT`—for completed, failed, cancelled, and total counts—avoiding the need for subqueries or `CASE` inside the `SUM`. The success rate is derived inline as a ratio of completed to total, wrapped in `NULLIF` to safely handle months with zero runs. `COUNT(DISTINCT User_ID)` and `COUNT(DISTINCT Model_ID)` within the same `GROUP BY` measure team breadth—how many people and how many distinct models were active each month.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Training_Run |
| **Key SQL Concepts** | `TO_CHAR()` for date truncation to month, `FILTER (WHERE ...)` multi-condition counting, `NULLIF` for safe division, `COUNT(DISTINCT ...)`, time-series grouping and ordering |

---

### 8. 🎯 Best Model Version per Problem Type Using Partitioned Ranking

The model registry spans several problem types—classification, regression, NLP, object detection, and more. Each problem type has its own performance ceiling based on task complexity and data availability. Comparing a classification model's F1 score against an NLP model's F1 score directly is misleading. The meaningful question is: within each problem type, which specific model version is performing best? This requires partitioned ranking that resets and operates independently for each problem type.

The query uses a CTE named `scored` where `RANK() OVER (PARTITION BY m.Problem_Type ORDER BY AVG(em.F1_Score) DESC)` computes a rank that starts fresh at 1 for each problem type. Metrics are averaged across all runs for each model-version combination before ranking, preventing high-run-count models from benefiting unfairly from lucky individual snapshots. The outer query simply filters `WHERE type_rank = 1`, returning exactly one champion row per problem type. This is a clean and composable pattern—the CTE handles computation, the outer query handles selection.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Evaluation_Metric, Training_Run, Model_Version, Model |
| **Key SQL Concepts** | CTE with `RANK() OVER (PARTITION BY ...)`, `GROUP BY` before window function application, filtering by rank in outer query, `AVG` aggregation inside window ordering |

---

### 9. 🔬 Hyperparameter Sensitivity — Learning Rate vs. Final F1

The learning rate is among the most influential hyperparameters in gradient-based model training. Set too high, the optimiser overshoots and fails to converge; set too low, training stalls and underfits. The Hyperparameter table stores all parameters as VARCHAR values to accommodate diverse types, which means numeric comparisons require an explicit cast. This query extracts, casts, and bins learning rate values, then correlates them with final evaluation scores across all completed runs.

Two CTEs work in sequence. The first—`final_snap`—uses `DISTINCT ON (Run_ID)` ordered by `Snapshot_ID DESC` to retrieve only the last recorded metric snapshot per run, representing the model's converged state. The second—`lr_vals`—filters the Hyperparameter table for rows where `Parameter_Name = 'learning_rate'` and casts the stored string value to `NUMERIC`. A `CASE` expression then maps raw numeric values into labelled buckets (very_low through very_high), enabling categorical analysis and easy visualisation. The join connects these two derivations back to model and version metadata.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Evaluation_Metric, Hyperparameter, Training_Run, Model_Version, Model |
| **Key SQL Concepts** | `DISTINCT ON` for last-row-per-group, `CAST()` for type conversion, chained CTEs, `CASE` expression for numeric binning, multi-CTE join pattern |

---

### 10. 🏁 End-to-End Model Pipeline Summary Using Multiple CTEs

Tracking a model from its first dataset ingestion through training, evaluation, and finally deployment requires joining information from nearly every table in the schema. Without a structured approach, this produces an unwieldy query that is hard to read and maintain. This query uses three independent CTEs that each solve one stage of the pipeline, then brings them together in a final `LEFT JOIN` to produce one comprehensive row per model.

`best_run` uses `DISTINCT ON (Model_ID)` ordered by F1 score descending to capture the single best training outcome per model. `latest_deploy` uses `DISTINCT ON (Model_ID)` ordered by `Deployed_At` descending to find each model's most recent deployment. `dataset_summary` aggregates all datasets used across completed runs into a pipe-separated string per model using `STRING_AGG`. The final `SELECT` joins all three back to the Model table using `LEFT JOIN`, ensuring models with no runs or no deployments still appear. A `CASE` expression derives a lifecycle_status label—from LIVE & HIGH PERFORMING down to NO COMPLETED RUNS—and the `ORDER BY` on this label sorts the result so the most actionable rows appear first.

| 📑 Element | 🔍 Details |
| --- | --- |
| **Tables Involved** | Model, Training_Run, Evaluation_Metric, Model_Version, Deployment, Dataset_Used, Dataset |
| **Key SQL Concepts** | Multiple independent CTEs, `DISTINCT ON` for best/latest row selection, `STRING_AGG` for aggregated string output, `LEFT JOIN` to preserve all models, `CASE` expression for lifecycle classification, custom `ORDER BY` using `CASE` |
