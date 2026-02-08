use serde_json::json;

pub async fn sleep_start(device: Option<&str>) {
    let mut body = json!({
        "command": "sleep.start",
        "params": {},
    });
    if let Some(dev) = device {
        body["device_id"] = json!(dev);
    }

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(resp) => {
            if resp.get("status").and_then(|s| s.as_str()) == Some("ok") {
                println!("Sleep mode activated — screen will stay on");
            } else {
                println!("{}", serde_json::to_string_pretty(&resp).unwrap());
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}

pub async fn sleep_stop(device: Option<&str>) {
    let mut body = json!({
        "command": "sleep.stop",
        "params": {},
    });
    if let Some(dev) = device {
        body["device_id"] = json!(dev);
    }

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(resp) => {
            if resp.get("status").and_then(|s| s.as_str()) == Some("ok") {
                println!("Sleep mode deactivated");
            } else {
                println!("{}", serde_json::to_string_pretty(&resp).unwrap());
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}
