# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  bucket_data_name           = "${data.google_project.environment.project_id}-${var.environment_name}-data"
  bucket_model_name          = "${data.google_project.environment.project_id}-${var.environment_name}-model"
  data_preparation_ksa       = "data-preparation"
  data_processing_ksa        = "data-processing"
  fine_tuning_ksa            = "fine-tuning"
  model_evaluation_ksa       = "model-evaluation"
  repo_container_images_id   = var.environment_name
  repo_container_images_url  = "${google_artifact_registry_repository.container_images.location}-docker.pkg.dev/${google_artifact_registry_repository.container_images.project}/${local.repo_container_images_id}"
  wi_member_principal_prefix = "principal://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/subject/ns/${var.namespace}/sa"
}

# SERVICES
###############################################################################

resource "google_project_service" "aiplatform_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "aiplatform.googleapis.com"
}

resource "google_project_service" "artifactregistry_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cloudbuild_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudbuild.googleapis.com"
}

# ARTIFACT REGISTRY
###############################################################################
resource "google_artifact_registry_repository" "container_images" {
  format        = "DOCKER"
  location      = var.subnet_01_region
  project       = google_project_service.artifactregistry_googleapis_com.project
  repository_id = local.repo_container_images_id
}

# GCS
###############################################################################
resource "google_storage_bucket" "data" {
  force_destroy               = false
  location                    = var.subnet_01_region
  name                        = local.bucket_data_name
  project                     = data.google_project.environment.project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "model" {
  force_destroy               = false
  location                    = var.subnet_01_region
  name                        = local.bucket_model_name
  project                     = data.google_project.environment.project_id
  uniform_bucket_level_access = true
}

# KSA
###############################################################################
resource "kubernetes_service_account_v1" "data_processing" {
  depends_on = [
    null_resource.git_cred_secret_ns,
    null_resource.namespace_manifests
  ]

  metadata {
    name      = local.data_processing_ksa
    namespace = var.namespace
  }
}

resource "kubernetes_service_account_v1" "data_preparation" {
  depends_on = [
    null_resource.git_cred_secret_ns,
    null_resource.namespace_manifests
  ]

  metadata {
    name      = local.data_preparation_ksa
    namespace = var.namespace
  }
}

resource "kubernetes_service_account_v1" "fine_tuning" {
  depends_on = [
    null_resource.git_cred_secret_ns,
    null_resource.namespace_manifests
  ]

  metadata {
    name      = local.fine_tuning_ksa
    namespace = var.namespace
  }
}

resource "kubernetes_service_account_v1" "model_evaluation" {
  depends_on = [
    null_resource.git_cred_secret_ns,
    null_resource.namespace_manifests
  ]

  metadata {
    name      = local.model_evaluation_ksa
    namespace = var.namespace
  }
}

# IAM
###############################################################################
resource "google_storage_bucket_iam_member" "data_bucket_ray_head_storage_object_viewer" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.ray_head_kubernetes_service_account}"
  role   = "roles/storage.objectViewer"
}

resource "google_storage_bucket_iam_member" "data_bucket_ray_worker_storage_object_admin" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.ray_worker_kubernetes_service_account}"
  role   = "roles/storage.objectAdmin"
}

resource "google_storage_bucket_iam_member" "data_bucket_data_processing_ksa_storage_object_user" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.data_processing_ksa}"
  role   = "roles/storage.objectUser"
}

resource "google_storage_bucket_iam_member" "data_bucket_data_preparation_storage_object_user" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.data_preparation_ksa}"
  role   = "roles/storage.objectUser"
}

resource "google_project_iam_member" "data_preparation_aiplatform_user" {
  project = data.google_project.environment.project_id
  member  = "${local.wi_member_principal_prefix}/${local.data_preparation_ksa}"
  role    = "roles/aiplatform.user"
}

resource "google_storage_bucket_iam_member" "data_bucket_fine_tuning_storage_object_user" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.fine_tuning_ksa}"
  role   = "roles/storage.objectUser"
}

resource "google_storage_bucket_iam_member" "model_bucket_fine_tuning_storage_object_user" {
  bucket = google_storage_bucket.model.name
  member = "${local.wi_member_principal_prefix}/${local.fine_tuning_ksa}"
  role   = "roles/storage.objectUser"
}

resource "google_storage_bucket_iam_member" "data_bucket_model_evaluation_storage_storage_insights_collector_service" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.model_evaluation_ksa}"
  role   = "roles/storage.insightsCollectorService"
}

resource "google_storage_bucket_iam_member" "data_bucket_model_evaluation_storage_object_user" {
  bucket = google_storage_bucket.data.name
  member = "${local.wi_member_principal_prefix}/${local.model_evaluation_ksa}"
  role   = "roles/storage.objectUser"
}

resource "google_storage_bucket_iam_member" "model_bucket_model_evaluation_storage_object_user" {
  bucket = google_storage_bucket.model.name
  member = "${local.wi_member_principal_prefix}/${local.model_evaluation_ksa}"
  role   = "roles/storage.objectUser"
}

output "environment_configuration" {
  value = <<EOT
MLP_AR_REPO_URL="${local.repo_container_images_url}"
MLP_CLUSTER_NAME="${local.cluster_name}"
MLP_DATA_BUCKET="${local.bucket_data_name}"
MLP_DATA_PREPARATION_IMAGE="${local.repo_container_images_url}/data-preparation:1.0.0"
MLP_DATA_PREPARATION_KSA="${local.data_preparation_ksa}"
MLP_DATA_PROCESSING_IMAGE="${local.repo_container_images_url}/data-processing:1.0.0"
MLP_DATA_PROCESSING_KSA="${local.data_processing_ksa}"
MLP_ENVIRONMENT_NAME="${var.environment_name}"
MLP_FINE_TUNING_IMAGE="${local.repo_container_images_url}/fine-tuning:1.0.0"
MLP_FINE_TUNING_KSA="${local.fine_tuning_ksa}"
MLP_KUBERNETES_NAMESPACE="${var.namespace}"
MLP_MODEL_BUCKET="${local.bucket_model_name}"
MLP_MODEL_EVALUATION_IMAGE="${local.repo_container_images_url}/model-evaluation:1.0.0"
MLP_MODEL_EVALUATION_KSA="${local.model_evaluation_ksa}"
MLP_PROJECT_ID="${data.google_project.environment.project_id}"
MLP_PROJECT_NUMBER="${data.google_project.environment.number}"
MLP_RAY_DASHBOARD_NAMESPACE_ENDPOINT="https://${local.ray_dashboard_endpoint}"
EOT
}