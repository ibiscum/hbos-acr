//! Status API for input sources.

use crate::inputs::inputs_status;
use rocket::get;
use rocket::serde::json::Json;

/// Report the configured input sources, their bound devices and last keypress.
///
/// This is the "is my remote detected?" endpoint.
#[get("/")]
pub fn get_inputs_status() -> Json<serde_json::Value> {
    Json(inputs_status())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_inputs_status_has_inputs_key() {
        let status = get_inputs_status().into_inner();
        assert!(status.get("inputs").is_some());
        let inputs = status.get("inputs").unwrap().as_array().unwrap();
        // No input sources are configured in unit-test context.
        assert!(inputs.is_empty());
    }
}
