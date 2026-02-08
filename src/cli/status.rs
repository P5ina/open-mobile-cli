pub async fn server_status() {
    match super::api_request(reqwest::Method::GET, "/api/status", None).await {
        Ok(resp) => {
            println!("Server Status:");
            if let Some(v) = resp.get("version").and_then(|v| v.as_str()) {
                println!("  Version:        {v}");
            }
            if let Some(u) = resp.get("uptime_secs").and_then(|v| v.as_u64()) {
                let h = u / 3600;
                let m = (u % 3600) / 60;
                let s = u % 60;
                println!("  Uptime:         {h}h {m}m {s}s");
            }
            if let Some(o) = resp.get("devices_online") {
                println!("  Devices online: {o}");
            }
            if let Some(t) = resp.get("devices_total") {
                println!("  Devices total:  {t}");
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}
