use serde_json::json;

pub async fn send_notification(message: &str, priority: &str) {
    let body = json!({
        "command": "notify.send",
        "params": {
            "title": "omcli",
            "body": message,
            "priority": priority,
        },
    });

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(_) => println!("Notification sent"),
        Err(e) => eprintln!("Error: {e}"),
    }
}
