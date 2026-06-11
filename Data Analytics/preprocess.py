"""
preprocess.py
=============
chronos_ml — Data Cleaning & Feature Engineering Module

All data preparation logic lives here as pure functions.
Import this file into any notebook or script:

    from preprocess import load_data, clean_data, remove_outliers, engineer_features, get_feature_lists

No notebook-specific code here — no plots, no uploads, no file dialogs.
"""

import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text


# ─────────────────────────────────────────────────────────────
# SECTION 1 — DATABASE CONNECTION
# ─────────────────────────────────────────────────────────────

def get_engine(connection_string: str):
    """
    Create and return a SQLAlchemy engine from a connection string.

    Parameters
    ----------
    connection_string : str
        Full PostgreSQL connection string including credentials.

    Returns
    -------
    sqlalchemy.engine.Engine
    """
    engine = create_engine(connection_string)
    # Test connection immediately so errors are caught early
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return engine


def load_data(engine) -> pd.DataFrame:
    """
    Pull the master ML analytical table directly from the live Neon database.
    Runs the full 7-CTE join query and returns one row per training run.

    Parameters
    ----------
    engine : sqlalchemy.engine.Engine
        Connected engine from get_engine()

    Returns
    -------
    pd.DataFrame
        Raw master DataFrame — one row per training run, all features and targets included.
    """
    query = """
    SET search_path TO chronos_ml;

    WITH

    final_snap AS (
      SELECT DISTINCT ON (Run_ID)
        Run_ID,
        F1_Score,
        Accuracy,
        Precision_Score,
        Recall,
        Validation_Loss,
        Snapshot_ID AS total_snapshots
      FROM Evaluation_Metric
      ORDER BY Run_ID, Snapshot_ID DESC
    ),

    first_snap AS (
      SELECT DISTINCT ON (Run_ID)
        Run_ID,
        F1_Score    AS first_f1,
        Accuracy    AS first_accuracy,
        Validation_Loss AS first_vloss
      FROM Evaluation_Metric
      ORDER BY Run_ID, Snapshot_ID ASC
    ),

    hp_pivot AS (
      SELECT
        Run_ID,
        MAX(CASE WHEN Parameter_Name = 'learning_rate'    THEN Value END) AS learning_rate,
        MAX(CASE WHEN Parameter_Name = 'n_estimators'     THEN Value END) AS n_estimators,
        MAX(CASE WHEN Parameter_Name = 'max_depth'        THEN Value END) AS max_depth,
        MAX(CASE WHEN Parameter_Name = 'batch_size'       THEN Value END) AS batch_size,
        MAX(CASE WHEN Parameter_Name = 'epochs'           THEN Value END) AS epochs,
        MAX(CASE WHEN Parameter_Name = 'num_leaves'       THEN Value END) AS num_leaves,
        MAX(CASE WHEN Parameter_Name = 'subsample'        THEN Value END) AS subsample,
        MAX(CASE WHEN Parameter_Name = 'dropout'          THEN Value END) AS dropout,
        MAX(CASE WHEN Parameter_Name = 'weight_decay'     THEN Value END) AS weight_decay,
        MAX(CASE WHEN Parameter_Name = 'warmup_steps'     THEN Value END) AS warmup_steps,
        MAX(CASE WHEN Parameter_Name = 'n_clusters'       THEN Value END) AS n_clusters,
        MAX(CASE WHEN Parameter_Name = 'gamma'            THEN Value END) AS gamma,
        MAX(CASE WHEN Parameter_Name = 'clip_range'       THEN Value END) AS clip_range,
        MAX(CASE WHEN Parameter_Name = 'reg_lambda'       THEN Value END) AS reg_lambda,
        MAX(CASE WHEN Parameter_Name = 'colsample_bytree' THEN Value END) AS colsample_bytree,
        COUNT(*) AS total_hyperparams
      FROM Hyperparameter
      GROUP BY Run_ID
    ),

    dataset_info AS (
      SELECT
        du.Run_ID,
        SUM(dv.Num_Rows)              AS total_train_rows,
        MAX(dv.Num_Features)          AS max_features,
        AVG(dv.Num_Features)          AS avg_features,
        COUNT(DISTINCT du.Dataset_ID) AS dataset_count,
        MAX(dv.Num_Rows)              AS largest_dataset_rows,
        MIN(dv.Num_Rows)              AS smallest_dataset_rows
      FROM Dataset_Used du
      JOIN Dataset_Version dv
        ON dv.Dataset_ID = du.Dataset_ID
        AND dv.Version_No = du.Version_No
      WHERE du.Split_Type = 'Train'
      GROUP BY du.Run_ID
    ),

    deployment_flag AS (
      SELECT
        tr.Run_ID,
        COUNT(DISTINCT dep.Deployment_ID)                           AS deployment_count,
        MAX(CASE WHEN dep.Status = 'Production' THEN 1 ELSE 0 END) AS reached_production,
        MAX(CASE WHEN dep.Status = 'Retired'    THEN 1 ELSE 0 END) AS was_retired
      FROM Training_Run tr
      LEFT JOIN Deployment dep
        ON dep.Model_ID        = tr.Model_ID
        AND dep.Version_Number = tr.Version_No
      GROUP BY tr.Run_ID
    ),

    artifact_info AS (
      SELECT
        Run_ID,
        COUNT(*)                                  AS artifact_count,
        ROUND(SUM(File_Size)/1073741824.0, 3)     AS artifact_size_gb
      FROM Model_Artifact
      GROUP BY Run_ID
    ),

    user_info AS (
      SELECT
        u.User_ID,
        u.Role AS user_role,
        COUNT(DISTINCT tr2.Run_ID) AS user_total_runs,
        ROUND(
          COUNT(DISTINCT tr2.Run_ID) FILTER (WHERE tr2.Status = 'Completed')::numeric
          / NULLIF(COUNT(DISTINCT tr2.Run_ID), 0) * 100, 1
        ) AS user_success_rate_pct
      FROM Users u
      LEFT JOIN Training_Run tr2 ON tr2.User_ID = u.User_ID
      GROUP BY u.User_ID, u.Role
    )

    SELECT
      tr.Run_ID                                                       AS run_id,
      m.Model_Name                                                    AS model_name,
      m.Category                                                      AS category,
      m.Problem_Type                                                  AS problem_type,
      m.License_Type                                                  AS license_type,
      m.Is_Public::INT                                                AS is_public,
      mv.Algorithm                                                    AS algorithm,
      mv.Status                                                       AS version_status,
      tr.Status                                                       AS run_status,
      CASE WHEN tr.Status = 'Completed' THEN 1 ELSE 0 END            AS run_success,
      ROUND(EXTRACT(EPOCH FROM
        COALESCE(tr.End_Time, tr.Start_Time) - tr.Start_Time
      ) / 3600.0, 4)                                                  AS duration_hours,
      EXTRACT(HOUR  FROM tr.Start_Time)                              AS start_hour,
      EXTRACT(DOW   FROM tr.Start_Time)                              AS start_day_of_week,
      EXTRACT(MONTH FROM tr.Start_Time)                              AS start_month,
      EXTRACT(YEAR  FROM tr.Start_Time)                              AS start_year,
      ui.user_role,
      ui.user_total_runs,
      ui.user_success_rate_pct,
      hp.learning_rate::NUMERIC                                       AS learning_rate,
      hp.n_estimators::NUMERIC                                        AS n_estimators,
      hp.max_depth::NUMERIC                                           AS max_depth,
      hp.batch_size::NUMERIC                                          AS batch_size,
      hp.epochs::NUMERIC                                              AS epochs,
      hp.num_leaves::NUMERIC                                          AS num_leaves,
      hp.subsample::NUMERIC                                           AS subsample,
      hp.dropout::NUMERIC                                             AS dropout,
      hp.weight_decay::NUMERIC                                        AS weight_decay,
      hp.warmup_steps::NUMERIC                                        AS warmup_steps,
      hp.n_clusters::NUMERIC                                          AS n_clusters,
      hp.gamma::NUMERIC                                               AS gamma,
      hp.clip_range::NUMERIC                                          AS clip_range,
      hp.reg_lambda::NUMERIC                                          AS reg_lambda,
      hp.colsample_bytree::NUMERIC                                    AS colsample_bytree,
      COALESCE(hp.total_hyperparams, 0)                               AS total_hyperparams,
      COALESCE(di.total_train_rows,      0)                           AS total_train_rows,
      COALESCE(di.max_features,          0)                           AS max_features,
      COALESCE(di.avg_features,          0)                           AS avg_features,
      COALESCE(di.dataset_count,         0)                           AS dataset_count,
      COALESCE(di.largest_dataset_rows,  0)                           AS largest_dataset_rows,
      COALESCE(di.smallest_dataset_rows, 0)                           AS smallest_dataset_rows,
      fs.F1_Score                                                     AS final_f1,
      fs.Accuracy                                                     AS final_accuracy,
      fs.Precision_Score                                              AS final_precision,
      fs.Recall                                                       AS final_recall,
      fs.Validation_Loss                                              AS final_vloss,
      fs.total_snapshots,
      COALESCE(df.deployment_count,    0)                             AS deployment_count,
      COALESCE(df.reached_production,  0)                             AS reached_production,
      COALESCE(df.was_retired,         0)                             AS was_retired,
      COALESCE(ai.artifact_count,      0)                             AS artifact_count,
      COALESCE(ai.artifact_size_gb,    0)                             AS artifact_size_gb
    FROM Training_Run tr
    JOIN Model_Version mv
      ON  mv.Model_ID   = tr.Model_ID
      AND mv.Version_No = tr.Version_No
    JOIN Model m ON m.Model_ID = tr.Model_ID
    LEFT JOIN final_snap    fs  ON fs.Run_ID  = tr.Run_ID
    LEFT JOIN first_snap    fst ON fst.Run_ID = tr.Run_ID
    LEFT JOIN hp_pivot      hp  ON hp.Run_ID  = tr.Run_ID
    LEFT JOIN dataset_info  di  ON di.Run_ID  = tr.Run_ID
    LEFT JOIN deployment_flag df ON df.Run_ID = tr.Run_ID
    LEFT JOIN artifact_info ai  ON ai.Run_ID  = tr.Run_ID
    LEFT JOIN user_info     ui  ON ui.User_ID = tr.User_ID
    ORDER BY tr.Start_Time ASC;
    """
    df = pd.read_sql(query, engine)
    print(f"[load_data] Loaded {len(df)} rows × {df.shape[1]} columns from Neon")
    return df


# ─────────────────────────────────────────────────────────────
# SECTION 2 — CLEANING
# ─────────────────────────────────────────────────────────────

# Columns that carry no predictive signal or directly leak the target
DROP_COLS = [
    'run_id', 'model_name',
    'run_status',           # leakage — encodes run_success
    'final_accuracy',       # correlated targets — keep only final_f1
    'final_precision',
    'final_recall',
    'final_vloss',
]

NUMERIC_COLS = [
    'learning_rate', 'n_estimators', 'max_depth', 'batch_size',
    'epochs', 'num_leaves', 'subsample', 'dropout', 'weight_decay',
    'warmup_steps', 'n_clusters', 'gamma', 'clip_range', 'reg_lambda',
    'colsample_bytree', 'total_hyperparams', 'total_train_rows',
    'max_features', 'avg_features', 'dataset_count',
    'largest_dataset_rows', 'smallest_dataset_rows',
    'duration_hours', 'start_hour', 'start_day_of_week',
    'start_month', 'start_year', 'user_total_runs',
    'user_success_rate_pct', 'artifact_count', 'artifact_size_gb',
    'deployment_count', 'reached_production', 'was_retired',
    'total_snapshots', 'is_public', 'final_f1',
]

CAT_COLS = [
    'category', 'problem_type', 'algorithm',
    'license_type', 'version_status', 'user_role',
]


def clean_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Apply all data cleaning steps to the raw DataFrame.

    Steps performed:
      1. Drop leakage and identifier columns
      2. Convert numeric columns from object/string to float
      3. Normalise categorical columns to lowercase stripped strings
      4. Drop rows where the classification target (run_success) is null

    Parameters
    ----------
    df : pd.DataFrame
        Raw DataFrame from load_data()

    Returns
    -------
    pd.DataFrame
        Cleaned DataFrame — same rows (minus nulls in target), corrected dtypes
    """
    df = df.copy()

    # 1. Drop leakage / identifier columns
    to_drop = [c for c in DROP_COLS if c in df.columns]
    df.drop(columns=to_drop, inplace=True)

    # 2. Fix numeric types
    for col in NUMERIC_COLS:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')

    # 3. Normalise categoricals
    for col in CAT_COLS:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip().str.lower()

    # 4. Drop rows with no target
    before = len(df)
    df = df.dropna(subset=['run_success'])
    dropped = before - len(df)
    if dropped > 0:
        print(f"[clean_data] Dropped {dropped} rows with null run_success")

    print(f"[clean_data] Done — {df.shape[0]} rows × {df.shape[1]} columns")
    return df


# ─────────────────────────────────────────────────────────────
# SECTION 3 — OUTLIER REMOVAL
# ─────────────────────────────────────────────────────────────

# Columns to apply IQR capping on
OUTLIER_COLS = [
    'learning_rate', 'n_estimators', 'max_depth', 'batch_size',
    'epochs', 'total_train_rows', 'duration_hours',
    'artifact_size_gb', 'user_total_runs', 'total_snapshots',
]


def remove_outliers(df: pd.DataFrame,
                    cols: list = None,
                    multiplier: float = 1.5) -> pd.DataFrame:
    """
    Cap outliers using the IQR (Interquartile Range) method.
    Values beyond Q1 - k*IQR or Q3 + k*IQR are clipped to the fence value.
    Rows are NOT dropped — values are winsorised (capped at fence).

    Parameters
    ----------
    df          : pd.DataFrame — cleaned DataFrame from clean_data()
    cols        : list of column names to apply outlier capping on.
                  Defaults to OUTLIER_COLS if None.
    multiplier  : float — IQR multiplier for fence calculation. Default 1.5.

    Returns
    -------
    pd.DataFrame
        DataFrame with outlier values capped.
    dict
        Report showing fences and outlier counts per column.
    """
    df     = df.copy()
    cols   = cols or [c for c in OUTLIER_COLS if c in df.columns]
    report = {}

    for col in cols:
        q1  = df[col].quantile(0.25)
        q3  = df[col].quantile(0.75)
        iqr = q3 - q1
        lo  = q1 - multiplier * iqr
        hi  = q3 + multiplier * iqr

        n_out = ((df[col] < lo) | (df[col] > hi)).sum()
        df[col] = df[col].clip(lower=lo, upper=hi)

        report[col] = {
            'lower_fence': round(lo, 4),
            'upper_fence': round(hi, 4),
            'outliers_capped': int(n_out),
        }

    print(f"[remove_outliers] Capped outliers in {len(cols)} columns")
    return df, report


# ─────────────────────────────────────────────────────────────
# SECTION 4 — FEATURE ENGINEERING
# ─────────────────────────────────────────────────────────────

DL_ALGOS  = ['bert','distilbert','roberta','resnet','efficientnet',
             'mobilenet','vgg','densenet','lstm','gpt','t5','yolo']
ENSEMBLE  = ['random forest','xgboost','lightgbm','gradient boosting',
             'adaboost','catboost']


def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Create all derived and interaction features from cleaned data.

    New columns created:
      - log_total_train_rows     : log1p of training row count
      - log_n_estimators         : log1p of n_estimators
      - lr_x_epochs              : learning_rate × epochs interaction
      - data_richness            : log(rows) × log(features) — dataset value score
      - feature_density          : max_features / (dataset_count + 1)
      - hp_completeness          : fraction of key HPs that are filled (0–1)
      - is_deep_learning         : 1 if algorithm is a DL framework
      - is_ensemble              : 1 if algorithm is an ensemble method
      - is_business_hours        : 1 if run started between 9am–6pm
      - is_weekend               : 1 if run started Saturday or Sunday
      - dataset_complexity_score : log(rows) × max_features

    Parameters
    ----------
    df : pd.DataFrame
        Cleaned + outlier-removed DataFrame

    Returns
    -------
    pd.DataFrame
        DataFrame with all new feature columns appended
    """
    df = df.copy()

    # Log transforms for right-skewed distributions
    if 'total_train_rows' in df.columns:
        df['log_total_train_rows'] = np.log1p(df['total_train_rows'])

    if 'n_estimators' in df.columns:
        df['log_n_estimators'] = np.log1p(df['n_estimators'].fillna(0))

    # Interaction features
    if 'learning_rate' in df.columns and 'epochs' in df.columns:
        df['lr_x_epochs'] = (
            df['learning_rate'].fillna(0) * df['epochs'].fillna(0)
        )

    if 'log_total_train_rows' in df.columns and 'max_features' in df.columns:
        df['data_richness'] = (
            df['log_total_train_rows'] *
            np.log1p(df['max_features'].fillna(0))
        )

    if 'max_features' in df.columns and 'dataset_count' in df.columns:
        df['feature_density'] = (
            df['max_features'].fillna(0) /
            (df['dataset_count'].fillna(1) + 1)
        )

    if 'log_total_train_rows' in df.columns and 'max_features' in df.columns:
        df['dataset_complexity_score'] = (
            df['log_total_train_rows'] * df['max_features'].fillna(0)
        ).round(4)

    # Hyperparameter completeness — fraction of key HPs filled per run
    hp_key_cols = [c for c in ['learning_rate', 'n_estimators', 'max_depth',
                                'batch_size', 'epochs', 'subsample', 'dropout']
                   if c in df.columns]
    if hp_key_cols:
        df['hp_completeness'] = df[hp_key_cols].notna().sum(axis=1) / len(hp_key_cols)

    # Algorithm family flags
    if 'algorithm' in df.columns:
        algo = df['algorithm'].str.lower().fillna('')
        df['is_deep_learning'] = algo.str.contains('|'.join(DL_ALGOS), na=False).astype(int)
        df['is_ensemble']      = algo.str.contains('|'.join(ENSEMBLE),  na=False).astype(int)

    # Time-based flags
    if 'start_hour' in df.columns:
        df['is_business_hours'] = df['start_hour'].between(9, 18).astype(int)

    if 'start_day_of_week' in df.columns:
        df['is_weekend'] = df['start_day_of_week'].isin([0, 6]).astype(int)

    new_cols = ['log_total_train_rows', 'log_n_estimators', 'lr_x_epochs',
                'data_richness', 'feature_density', 'dataset_complexity_score',
                'hp_completeness', 'is_deep_learning', 'is_ensemble',
                'is_business_hours', 'is_weekend']
    created = [c for c in new_cols if c in df.columns]
    print(f"[engineer_features] Created {len(created)} new features: {created}")
    return df


# ─────────────────────────────────────────────────────────────
# SECTION 5 — FEATURE LISTS
# ─────────────────────────────────────────────────────────────

def get_feature_lists(df: pd.DataFrame):
    """
    Return the final numeric and categorical feature lists
    based on what columns are actually present in the DataFrame.
    Call this AFTER engineer_features() so derived columns are included.

    Parameters
    ----------
    df : pd.DataFrame
        Fully processed DataFrame after all preprocessing steps

    Returns
    -------
    numeric_features : list
    categorical_features : list
    all_features : list
    """
    candidate_numeric = [
        'learning_rate', 'n_estimators', 'max_depth', 'batch_size',
        'epochs', 'num_leaves', 'subsample', 'dropout', 'weight_decay',
        'warmup_steps', 'n_clusters', 'gamma', 'clip_range', 'reg_lambda',
        'colsample_bytree', 'total_hyperparams', 'hp_completeness',
        'log_total_train_rows', 'log_n_estimators', 'max_features',
        'avg_features', 'dataset_count', 'dataset_complexity_score',
        'data_richness', 'feature_density', 'duration_hours',
        'artifact_size_gb', 'total_snapshots', 'user_total_runs',
        'user_success_rate_pct', 'is_deep_learning', 'is_ensemble',
        'is_business_hours', 'is_weekend', 'lr_x_epochs',
        'is_public', 'start_hour', 'start_month', 'deployment_count',
    ]

    candidate_categorical = [
        'category', 'problem_type', 'algorithm',
        'user_role', 'license_type', 'version_status',
    ]

    numeric_features     = [c for c in candidate_numeric     if c in df.columns]
    categorical_features = [c for c in candidate_categorical if c in df.columns]
    all_features         = numeric_features + categorical_features

    print(f"[get_feature_lists] {len(numeric_features)} numeric + "
          f"{len(categorical_features)} categorical = {len(all_features)} total features")

    return numeric_features, categorical_features, all_features


# ─────────────────────────────────────────────────────────────
# SECTION 6 — FULL PIPELINE CONVENIENCE FUNCTION
# ─────────────────────────────────────────────────────────────

def run_full_pipeline(connection_string: str):
    """
    Convenience function — runs all preprocessing steps in one call.
    Returns fully processed DataFrame and feature lists ready for ML.

    Usage
    -----
        from preprocess import run_full_pipeline
        df, num_feats, cat_feats, all_feats = run_full_pipeline(CONNECTION_STRING)

    Parameters
    ----------
    connection_string : str

    Returns
    -------
    df              : pd.DataFrame — processed data
    numeric_feats   : list
    categorical_feats : list
    all_feats       : list
    outlier_report  : dict
    """
    print("=" * 50)
    print("  chronos_ml — Preprocessing Pipeline")
    print("=" * 50)

    engine          = get_engine(connection_string)
    df_raw          = load_data(engine)
    df_clean        = clean_data(df_raw)
    df_no_out, rpt  = remove_outliers(df_clean)
    df_final        = engineer_features(df_no_out)
    num_f, cat_f, all_f = get_feature_lists(df_final)

    print()
    print(f"  Final shape : {df_final.shape}")
    print(f"  Total feats : {len(all_f)}")
    print("=" * 50)

    return df_final, num_f, cat_f, all_f, rpt
