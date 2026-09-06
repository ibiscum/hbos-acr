use rocket::serde::json::Json;
use rocket::get;
use serde::{Deserialize, Serialize};
use log::{debug, error};
use crate::helpers::backgroundjobs::{get_all_jobs, BackgroundJob};

/// Response structure for background jobs listing
#[derive(Serialize, Deserialize)]
pub struct BackgroundJobsResponse {
    pub success: bool,
    pub jobs: Option<Vec<BackgroundJobInfo>>,
    pub message: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::helpers::backgroundjobs::BackgroundJob;

    #[test]
    fn test_background_job_info_completion_percentage() {
        let mut job = BackgroundJob::new("test-job".to_string(), "Test Job".to_string());
        job.total_items = Some(10);
        job.completed_items = Some(5);
        let info = BackgroundJobInfo::from(job);
        assert_eq!(info.completion_percentage, Some(50.0));
    }

    #[test]
    fn test_background_job_info_completion_percentage_zero_total() {
        let mut job = BackgroundJob::new("test-job".to_string(), "Test Job".to_string());
        job.total_items = Some(0);
        job.completed_items = Some(0);
        let info = BackgroundJobInfo::from(job);
        assert_eq!(info.completion_percentage, Some(100.0));
    }

    #[test]
    fn test_background_job_info_no_progress() {
        let job = BackgroundJob::new("test-job".to_string(), "Test Job".to_string());
        let info = BackgroundJobInfo::from(job);
        assert_eq!(info.completion_percentage, None);
    }
}

/// Enhanced background job information for API response
#[derive(Serialize, Deserialize)]
pub struct BackgroundJobInfo {
    pub id: String,
    pub name: String,
    pub start_time: u64,
    pub last_update: u64,
    pub progress: Option<String>,
    pub total_items: Option<usize>,
    pub completed_items: Option<usize>,
    pub duration_seconds: u64,
    pub time_since_last_update: u64,
    pub completion_percentage: Option<f64>,
    pub finished: bool,
    pub finish_time: Option<u64>,
}

impl From<BackgroundJob> for BackgroundJobInfo {
    fn from(job: BackgroundJob) -> Self {
        let completion_percentage = if let (Some(completed), Some(total)) = (job.completed_items, job.total_items) {
            if total > 0 {
                Some((completed as f64 / total as f64) * 100.0)
            } else {
                Some(100.0)
            }
        } else {
            None
        };

        Self {
            id: job.id.clone(),
            name: job.name.clone(),
            start_time: job.start_time,
            last_update: job.last_update,
            progress: job.progress.clone(),
            total_items: job.total_items,
            completed_items: job.completed_items,
            duration_seconds: job.duration_seconds(),
            time_since_last_update: job.time_since_last_update(),
            completion_percentage,
            finished: job.finished,
            finish_time: job.finish_time,
        }
    }
}

/// Response structure for error operations
#[derive(Serialize, Deserialize)]
pub struct ErrorResponse {
    pub success: bool,
    pub message: String,
}

/// Get all currently running background jobs
/// 
/// This endpoint retrieves information about all background jobs currently
/// running in the system, including their progress and timing information.
#[get("/jobs")]
pub fn get_background_jobs() -> Json<BackgroundJobsResponse> {
    debug!("API request: get background jobs");

    match get_all_jobs() {
        Ok(jobs) => {
            debug!("Successfully retrieved {} background jobs", jobs.len());
            
            let job_infos: Vec<BackgroundJobInfo> = jobs
                .into_iter()
                .map(BackgroundJobInfo::from)
                .collect();
            
            Json(BackgroundJobsResponse {
                success: true,
                jobs: Some(job_infos),
                message: None,
            })
        }
        Err(e) => {
            error!("Failed to retrieve background jobs: {}", e);
            Json(BackgroundJobsResponse {
                success: false,
                jobs: None,
                message: Some(format!("Failed to retrieve background jobs: {}", e)),
            })
        }
    }
}

/// Get information about a specific background job by ID
/// 
/// This endpoint retrieves detailed information about a specific background job.
#[get("/jobs/<job_id>")]
pub fn get_background_job(job_id: String) -> Json<BackgroundJobsResponse> {
    debug!("API request: get background job with ID: {}", job_id);

    match crate::helpers::backgroundjobs::get_job(&job_id) {
        Ok(Some(job)) => {
            debug!("Successfully retrieved background job: {}", job_id);
            
            let job_info = BackgroundJobInfo::from(job);
            
            Json(BackgroundJobsResponse {
                success: true,
                jobs: Some(vec![job_info]),
                message: None,
            })
        }
        Ok(None) => {
            debug!("Background job not found: {}", job_id);
            Json(BackgroundJobsResponse {
                success: false,
                jobs: None,
                message: Some(format!("Background job '{}' not found", job_id)),
            })
        }
        Err(e) => {
            error!("Failed to retrieve background job '{}': {}", job_id, e);
            Json(BackgroundJobsResponse {
                success: false,
                jobs: None,
                message: Some(format!("Failed to retrieve background job: {}", e)),
            })
        }
    }
}
