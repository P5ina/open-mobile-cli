use serde_json::json;

pub async fn alarm_start(sound: &str, message: Option<&str>, device: Option<&str>) {
    let mut params = json!({ "sound": sound });
    if let Some(msg) = message {
        params["message"] = json!(msg);
    }
    let mut body = json!({
        "command": "alarm.start",
        "params": params,
    });
    if let Some(dev) = device {
        body["device_id"] = json!(dev);
    }

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(resp) => {
            if resp.get("status").and_then(|s| s.as_str()) == Some("ok") {
                println!("Alarm started");
            } else {
                println!("{}", serde_json::to_string_pretty(&resp).unwrap());
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}

pub async fn alarm_stop(device: Option<&str>) {
    let mut body = json!({
        "command": "alarm.stop",
        "params": {},
    });
    if let Some(dev) = device {
        body["device_id"] = json!(dev);
    }

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(resp) => {
            if resp.get("status").and_then(|s| s.as_str()) == Some("ok") {
                println!("Alarm stopped");
            } else {
                println!("{}", serde_json::to_string_pretty(&resp).unwrap());
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}
