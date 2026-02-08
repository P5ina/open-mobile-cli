use serde_json::json;

pub async fn locate(device: Option<&str>) {
    let mut body = json!({
        "command": "location.get",
        "params": { "accuracy": "precise" },
    });
    if let Some(dev) = device {
        body["device_id"] = json!(dev);
    }

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(resp) => {
            if let Some(data) = resp.get("data") {
                if let Some(lat) = data.get("lat") {
                    if let Some(lon) = data.get("lon") {
                        println!("Location: {}, {}", lat, lon);
                        if let Some(acc) = data.get("accuracy") {
                            println!("Accuracy: {}m", acc);
                        }
                        return;
                    }
                }
                println!("{}", serde_json::to_string_pretty(data).unwrap());
            } else {
                println!("{}", serde_json::to_string_pretty(&resp).unwrap());
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}
