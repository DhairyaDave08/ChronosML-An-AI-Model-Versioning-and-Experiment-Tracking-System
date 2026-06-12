# ChronosML: An AI Model Versioning & Experiment Tracking System

ChronosML is an end-to-end MLOps metadata tracking framework designed to monitor, evaluate, and trace machine learning lifecycles. By decoupling database architecture from transient computing runtimes, it establishes a centralized system of record to capture hyperparameters, log artifact schemas, run multi-model A/B tests, and orchestrate real-time production feedback loops.

---

## 🧬 Relational Metadata Architecture

The foundation of ChronosML lies in a strict, relational database tracking engine containing 13 normalized tables to enforce referential integrity across all stages of the model lifecycle:

* **Users:** Registers system operators, data scientists, and ML engineers.
* **Model:** Defines the overarching machine learning application boundaries.
* **Model_Version:** Tracks linear model iterations and regulatory compliance states.
* **Training_Run:** Captures real-time execution states (Completed, Failed, Cancelled), timestamps, and operator references.
* **Hyperparameter:** Implements an elastic Entity-Attribute-Value (EAV) design to log variable algorithmic configurations dynamically.
* **Evaluation_Metric:** Stores multi-snapshot performance checks across the lifecycle of a training run.
* **Model_Artifact:** Maps physical disk serialization paths, binary structures, and file sizes.
* **Files & Model_Created:** Bridges dataset source tracking with target models.
* **Registers & Deploys:** Maps specific team contributions (Creator, Curator, Annotator, Reviewer) and cluster deployment roles (Owner, Operator, Observer).
* **Deployment:** Monitors active inference endpoints, environments (Staging, Production), and baseline comparison links.
* **Dataset_Used:** Links specific training runs to exact data versioning snapshots and splits (Train, Validation, Test, Full).

---

## 🤖 Predictive Machine Learning Engine

The system features two distinct predictive tracks to evaluate experimentation runs before deployment:
* **Classification:** Evaluates whether a specific run configuration will succeed (`run_success`).
* **Regression:** Predicts the final convergence capability metric (`final_f1`).

### Preprocessing & Data Imputation Pipeline
Because variable hyperparameter inputs introduce structural sparsity, data processing handles empty features via a Scikit-Learn `ColumnTransformer` pipeline:
* **Numeric Features:** Handled via median imputation and scaled via `StandardScaler`.
* **Categorical Features:** Processed via most-frequent mode imputation and mapped using `OrdinalEncoder`.

Models are evaluated via **Stratified 5-Fold Cross Validation** to protect against target class imbalances and prevent structural data leakages.

---

## 📊 Benchmarking & Experimentation Results

### 1. Classification & Discriminator Performance Matrix

| 🤖 Candidate Estimator | 🎯 Mean Cross-Validation F1-Score | 📈 Area Under Curve (AUC) |
| :--- | :---: | :---: |
| Logistic Regression | $0.8415 \pm 0.1021$ | $0.9560$ |
| Gradient Boosting | $0.8951 \pm 0.0906$ | $1.0000$ |
| **Random Forest (Selected)** | $\mathbf{0.9243 \pm 0.0571}$ | $\mathbf{1.0000}$ |

> 🏆 **Production Selection:** **Random Forest** was chosen as the active system discriminator due to its optimal handling of high-dimensional parameter configurations and low structural variance.

### 2. Continuous Performance Regression Drivers
The features are ranked below by their absolute correlation (|r|) with the target metric (final_f1) to map critical convergence drivers:

| Rank | Feature Name | Absolute Correlation (\|corr\|) | Engineering Type |
| :---: | :--- | :---: | :--- |
| 1 | `batch_size` | 0.7183 | Hyperparameter |
| 2 | `duration_hours` | 0.5955 | Runtime Telemetry |
| 3 | `data_richness` | 0.5799 | Engineered Interaction |
| 4 | `user_total_runs` | 0.5788 | Operator Context |
| 5 | `log_total_train_rows` | 0.5631 | Dataset Scale |
| 6 | `dataset_count` | 0.5410 | Relational Cardinality |
| 7 | `total_hyperparams` | 0.5410 | Dimensionality Index |
| 8 | `dataset_complexity_score` | 0.5398 | Non-linear Interaction |

## ⚖️ Copyright & License

Copyright © 2026 Dhairya Dave. All rights reserved.

Licensed under the MIT License. Portions of this project utilize cloud backend services and open-source packages subject to their respective terms and community licensing.
