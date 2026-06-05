CREATE SCHEMA chronos_ml;
SET search_path TO chronos_ml;

CREATE TABLE Users (
    User_ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Password_Hash VARCHAR(255) NOT NULL,
    Role VARCHAR(25) NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    Email VARCHAR(255) UNIQUE NOT NULL,
    First_Name VARCHAR(50) NOT NULL,
    Middle_Name VARCHAR(50),
    Last_Name VARCHAR(50),
    CONSTRAINT chk_users_role CHECK (Role IN ('Data Scientist', 'ML Engineer', 'Data Administrator', 'Surfer'))
);

CREATE TABLE Model (
    Model_ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Model_Name VARCHAR(100) NOT NULL,
    Description TEXT NOT NULL,
    Problem_Type VARCHAR(50) NOT NULL,
    License_Type VARCHAR(50) NOT NULL,
    Is_Public BOOLEAN DEFAULT FALSE NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    Category VARCHAR(50) NOT NULL,
    CONSTRAINT chk_model_category_type CHECK (Category IN ('Supervised Learning', 'Unsupervised Learning', 'Semi-Supervised Learning','Reinforcement Learning', 'Deep Learning','Other')),
    CONSTRAINT chk_model_problem_type CHECK (Problem_Type IN ('Classification', 'Regression', 'Clustering', 'Object Detection', 'NLP', 'Computer Vision', 'Generative', 'Other')),
    CONSTRAINT chk_model_license_type CHECK (License_Type IN ('MIT', 'Apache-2.0', 'GPL-3.0', 'CC-BY-4.0', 'Proprietary', 'Other'))
);

CREATE TABLE Dataset (
    Dataset_ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Dataset_Name VARCHAR(100) NOT NULL,
    Description TEXT NOT NULL,
    Status VARCHAR(20) NOT NULL,
    Source VARCHAR(255) NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    Is_Public BOOLEAN DEFAULT FALSE NOT NULL,
    CONSTRAINT chk_dataset_status CHECK (Status IN ('Active', 'Deprecated', 'Draft'))
);

CREATE TABLE Model_Version (
    Model_ID UUID REFERENCES Model(Model_ID) ON DELETE CASCADE,
    Version_No VARCHAR(20),
    Algorithm VARCHAR(100) NOT NULL,
    Status VARCHAR(50) NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    Description TEXT NOT NULL,
    PRIMARY KEY (Model_ID, Version_No),
    CONSTRAINT chk_model_version_status CHECK (Status IN ('Staging', 'Production', 'Archived', 'Deprecated'))
);

CREATE TABLE Dataset_Version (
    Dataset_ID UUID REFERENCES Dataset(Dataset_ID) ON DELETE CASCADE,
    Version_No VARCHAR(20),
    Changelog TEXT NOT NULL, 
    Num_Rows BIGINT NOT NULL,
    Num_Features INT NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (Dataset_ID, Version_No)
);

CREATE TABLE Training_Run (
    Run_ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Status VARCHAR(50) NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, 
    Start_Time TIMESTAMP NOT NULL,
    End_Time TIMESTAMP,
    User_ID UUID REFERENCES Users(User_ID) ON DELETE SET NULL,
    Model_ID UUID NOT NULL,
    Version_No VARCHAR(20) NOT NULL,
    FOREIGN KEY (Model_ID, Version_No) REFERENCES Model_Version(Model_ID, Version_No) ON DELETE CASCADE,
    CONSTRAINT chk_training_run_status CHECK (Status IN ('Pending', 'Running', 'Completed', 'Failed', 'Cancelled')),
    CONSTRAINT chk_training_run_times CHECK (End_Time IS NULL OR End_Time >= Start_Time)
);

CREATE TABLE Hyperparameter (
    Run_ID UUID REFERENCES Training_Run(Run_ID) 
    ON DELETE CASCADE,
    Parameter_Name VARCHAR(100),
    Data_Type VARCHAR(20) NOT NULL,
    Value VARCHAR(255) NOT NULL,
    PRIMARY KEY (Run_ID, Parameter_Name),
    CONSTRAINT chk_hyperparameter_data_type CHECK (Data_Type IN ('int', 'float', 'string', 'bool'))
);

CREATE TABLE Evaluation_Metric (
    Run_ID UUID REFERENCES Training_Run(Run_ID) ON DELETE CASCADE,
    Snapshot_ID INT,
    Recall NUMERIC(5,4) NOT NULL,
    Accuracy NUMERIC(5,4) NOT NULL,
    Recorded_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    Validation_Loss NUMERIC(10,4) NOT NULL,
    Precision_Score NUMERIC(5,4) NOT NULL,
    F1_Score NUMERIC(5,4) NOT NULL,
    PRIMARY KEY (Run_ID, Snapshot_ID),
    CONSTRAINT chk_eval_recall CHECK (Recall BETWEEN 0 AND 1),
    CONSTRAINT chk_eval_accuracy CHECK 
    (Accuracy BETWEEN 0 AND 1),
    CONSTRAINT chk_eval_precision CHECK 
    (Precision_Score BETWEEN 0 AND 1),
    CONSTRAINT chk_eval_f1 CHECK (F1_Score BETWEEN 0 AND 1),
    CONSTRAINT chk_eval_validation_loss CHECK 
    (Validation_Loss >= 0)
);

CREATE TABLE Model_Artifact (
    Artifact_ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    User_ID UUID REFERENCES Users(User_ID) ON DELETE SET NULL,
    Run_ID UUID REFERENCES Training_Run(Run_ID) ON 
    DELETE CASCADE,
    File_Size BIGINT NOT NULL,
    File_Path TEXT UNIQUE NOT NULL,
    Uploaded_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_artifact_file_size CHECK (File_Size > 0)
);

CREATE TABLE Files (
    Artifact_ID UUID REFERENCES Model_Artifact(Artifact_ID) ON DELETE CASCADE,
    File_Type VARCHAR(50),
    PRIMARY KEY (Artifact_ID, File_Type),
    CONSTRAINT chk_files_file_type CHECK (File_Type IN ('weights', 'config', 'script', 'tokenizer', 'onnx', 'checkpoint', 'log', 'other'))
);

CREATE TABLE Deployment (
    Deployment_ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Deployed_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    Status VARCHAR(50) NOT NULL,
    Retired_At TIMESTAMP,
    Server_Info TEXT NOT NULL,
    Environment VARCHAR(50) NOT NULL,
    Model_ID UUID NOT NULL,
    Version_Number VARCHAR(20) NOT NULL,
    Compared_With UUID REFERENCES Deployment(Deployment_ID) ON DELETE SET NULL,
    FOREIGN KEY (Model_ID, Version_Number) REFERENCES Model_Version(Model_ID, Version_No) ON DELETE CASCADE,
    CONSTRAINT chk_deployment_status CHECK (Status IN ('Staging', 'Production', 'Failed', 'Retired', 'Rolled Back')),
    CONSTRAINT chk_deployment_environment CHECK (Environment IN ('Development', 'Staging', 'Production')),
    CONSTRAINT chk_deployment_retired_at CHECK (Retired_At IS NULL OR Retired_At >= Deployed_At),
    CONSTRAINT chk_deployment_not_self_compare CHECK (Compared_With <> Deployment_ID)
);

CREATE TABLE Model_Created (
    User_ID UUID REFERENCES Users(User_ID) ON DELETE CASCADE,
    Model_ID UUID REFERENCES Model(Model_ID) ON DELETE CASCADE,
    Access_Level VARCHAR(30) NOT NULL,
    PRIMARY KEY (User_ID, Model_ID),
    CONSTRAINT chk_model_created_access_level CHECK (Access_Level IN ('Owner', 'Editor', 'Viewer'))
);

CREATE TABLE Registers (
    User_ID UUID REFERENCES Users(User_ID) ON DELETE CASCADE,
    Dataset_ID UUID REFERENCES Dataset(Dataset_ID) ON DELETE CASCADE,
    Contribution_Type VARCHAR(50) NOT NULL,
    PRIMARY KEY (User_ID, Dataset_ID),
    CONSTRAINT chk_registers_contribution_type CHECK (Contribution_Type IN ('Creator', 'Curator', 'Annotator', 'Reviewer'))
);

CREATE TABLE Deploys (
    Deployment_ID UUID REFERENCES Deployment(Deployment_ID) ON DELETE CASCADE,
    User_ID UUID REFERENCES Users(User_ID) ON DELETE CASCADE,
    Deployment_Role VARCHAR(30) NOT NULL,
    PRIMARY KEY (Deployment_ID, User_ID),
    CONSTRAINT chk_deploys_role CHECK (Deployment_Role IN ('Owner', 'Operator', 'Observer'))
);

CREATE TABLE Dataset_Used (
    Run_ID UUID REFERENCES Training_Run(Run_ID) ON DELETE CASCADE,
    Dataset_ID UUID,
    Version_No VARCHAR(20),
    Split_Type VARCHAR(20) NOT NULL,
    PRIMARY KEY (Run_ID, Dataset_ID, Version_No),
    FOREIGN KEY (Dataset_ID, Version_No) REFERENCES Dataset_Version(Dataset_ID, Version_No) ON DELETE CASCADE,
    CONSTRAINT chk_dataset_used_split_type CHECK (Split_Type IN  ('Train', 'Validation', 'Test', 'Full'))
);
