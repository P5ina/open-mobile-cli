use serde_json::json;

pub async fn pair(code: &str) {
    let body = json!({ "code": code });

    match super::api_request(reqwest::Method::POST, "/api/devices/pair", Some(body)).await {
        Ok(resp) => {
            let device_id = resp
                .get("device_id")
                .and_then(|v| v.as_str())
                .unwrap_or("?");
            let name = resp.get("name").and_then(|v| v.as_str()).unwrap_or("?");
            println!("Paired: {} ({})", name, device_id);
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}
