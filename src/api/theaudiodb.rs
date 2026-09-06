use rocket::serde::json::Json;
use rocket::{get};
use rocket::response::status::Custom;
use rocket::http::Status;
use serde::Serialize;
use crate::helpers::theaudiodb;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_the_audio_db_response_serialization_success() {
        let response = TheAudioDbResponse {
            mbid: "mbid-123".to_string(),
            success: true,
            data: Some(serde_json::json!({"artist": "Test"})),
            error: None,
        };
        let json = serde_json::to_string(&response).unwrap();
        assert!(json.contains("\"success\":true"));
        assert!(json.contains("\"mbid\":\"mbid-123\""));
    }

    #[test]
    fn test_the_audio_db_response_serialization_error() {
        let response = TheAudioDbResponse {
            mbid: "mbid-123".to_string(),
            success: false,
            data: None,
            error: Some("not found".to_string()),
        };
        let json = serde_json::to_string(&response).unwrap();
        assert!(json.contains("\"success\":false"));
        assert!(json.contains("\"error\":\"not found\""));
    }
}

/// Response structure for TheAudioDB lookup
#[derive(Serialize)]
pub struct TheAudioDbResponse {
    mbid: String,
    success: bool,
    data: Option<serde_json::Value>,
    error: Option<String>,
}

/// API endpoint to lookup artist information from TheAudioDB by MusicBrainz ID
/// 
/// This endpoint is primarily used for integration testing to verify that the
/// TheAudioDB module is working correctly.
/// 
/// # Path Parameters
/// * `mbid` - MusicBrainz ID of the artist to look up
/// 
/// # Returns
/// * 200 OK with artist data if found
/// * 404 Not Found if artist not found
/// * 503 Service Unavailable if TheAudioDB is disabled
/// * 500 Internal Server Error for other errors
#[get("/audiodb/mbid/<mbid>")]
pub fn lookup_artist_by_mbid(mbid: String) -> Result<Json<TheAudioDbResponse>, Custom<Json<TheAudioDbResponse>>> {
    // Check if TheAudioDB is enabled
    if !theaudiodb::is_enabled() {
        return Err(Custom(
            Status::ServiceUnavailable,
            Json(TheAudioDbResponse {
                mbid: mbid.clone(),
                success: false,
                data: None,
                error: Some("TheAudioDB lookups are disabled".to_string()),
            })
        ));
    }

    // Perform the lookup
    match theaudiodb::lookup_theaudiodb_by_mbid(&mbid) {
        Ok(artist_data) => {
            Ok(Json(TheAudioDbResponse {
                mbid,
                success: true,
                data: Some(artist_data),
                error: None,
            }))
        }
        Err(e) => {
            // Check if it's a "not found" error
            if e.contains("No artist found") {
                Err(Custom(
                    Status::NotFound,
                    Json(TheAudioDbResponse {
                        mbid,
                        success: false,
                        data: None,
                        error: Some(e),
                    })
                ))
            } else {
                // Other errors (API key, network, etc.)
                Err(Custom(
                    Status::InternalServerError,
                    Json(TheAudioDbResponse {
                        mbid,
                        success: false,
                        data: None,
                        error: Some(e),
                    })
                ))
            }
        }
    }
}
