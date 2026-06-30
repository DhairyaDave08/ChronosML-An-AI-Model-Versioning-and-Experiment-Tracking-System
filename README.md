# ChronosML: An AI Model Versioning & Experiment Tracking System

ChronosML is an end-to-end MLOps metadata tracking framework designed to monitor, evaluate, and trace machine learning lifecycles. By decoupling database architecture from transient computing runtimes, it establishes a centralized system of record to capture hyperparameters, artifact metadata, dataset lineage, deployment history, and experiment execution details across the complete model lifecycle.

---

## 🧬 Relational Metadata Architecture

The foundation of ChronosML lies in a normalized relational database consisting of 13 interconnected tables that maintain referential integrity across every stage of the machine learning workflow.

### Core Entities

- **Users:** Stores information about system operators, data scientists, and ML engineers.
- **Model:** Represents machine learning projects and their associated metadata.
- **Model_Version:** Maintains version history, lifecycle status, and version-specific information.
- **Training_Run:** Records execution details, timestamps, run status, and associated users.
- **Hyperparameter:** Uses an Entity-Attribute-Value (EAV) schema to flexibly store model hyperparameters.
- **Evaluation_Metric:** Stores evaluation metrics generated during individual training runs.
- **Model_Artifact:** Tracks serialized model files, storage paths, formats, and artifact metadata.
- **Files:** Maintains dataset and file metadata used throughout experimentation.
- **Model_Created:** Maps datasets and files to the models they contribute to.
- **Registers:** Records user roles such as Creator, Curator, Annotator, and Reviewer.
- **Deployment:** Stores deployment environments, endpoint details, and deployment status.
- **Deploys:** Maps deployment ownership and operational responsibilities.
- **Dataset_Used:** Links training runs with specific dataset versions and data splits.

---

## 🚀 Key Features

- Model version management
- Training run tracking and history
- Hyperparameter versioning using an EAV schema
- Artifact and dataset lineage tracking
- Deployment metadata management
- User role and ownership tracking
- Relational schema enforcing referential integrity
- Centralized experiment metadata repository



---

## ⚖️ License

Copyright © 2026 Dhairya Dave. All rights reserved.

Licensed under the MIT License. Portions of this project utilize cloud backend services and open-source packages subject to their respective licenses.
