pub async fn list_devices() {
    match super::api_request(reqwest::Method::GET, "/api/devices", None).await {
        Ok(resp) => {
            if let Some(devices) = resp.as_array() {
                if devices.is_empty() {
                    println!("No devices paired");
                    return;
                }
                println!("{:<38} {:<20} {:<10}", "ID", "NAME", "STATUS");
                println!("{}", "-".repeat(68));
                for d in devices {
                    let id = d.get("id").and_then(|v| v.as_str()).unwrap_or("?");
                    let name = d.get("name").and_then(|v| v.as_str()).unwrap_or("?");
                    let online = d.get("online").and_then(|v| v.as_bool()).unwrap_or(false);
                    let status = if online { "online" } else { "offline" };
                    println!("{:<38} {:<20} {:<10}", id, name, status);
                }
            } else {
                println!("{}", serde_json::to_string_pretty(&resp).unwrap());
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}
