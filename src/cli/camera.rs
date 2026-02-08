use base64::Engine;
use serde_json::json;
use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};

pub async fn camera_snap(facing: &str, output: Option<&str>, device: Option<&str>) {
    let mut body = json!({
        "command": "camera.snap",
        "params": { "facing": facing },
    });
    if let Some(dev) = device {
        body["device_id"] = json!(dev);
    }

    match super::api_request(reqwest::Method::POST, "/api/command", Some(body)).await {
        Ok(resp) => {
            // Check for device-side errors
            if resp.get("status").and_then(|s| s.as_str()) == Some("error") {
                let code = resp.get("error_code").and_then(|c| c.as_str()).unwrap_or("");
                if code == "USER_DECLINED" {
                    eprintln!("The photo was declined on the device.");
                } else {
                    let msg = resp.get("error").and_then(|e| e.as_str()).unwrap_or("Unknown error");
                    eprintln!("Error: {msg}");
                }
                return;
            }

            // Camera snap requires a live WebSocket connection — APNS can't return data
            if resp.get("data").and_then(|d| d.get("delivered_via")).and_then(|v| v.as_str())
                == Some("apns")
            {
                eprintln!("Error: camera snap requires the device to be connected via WebSocket");
                eprintln!("Open the app on the device and try again");
                return;
            }

            let b64 = match resp.get("data").and_then(|d| d.get("base64")).and_then(|v| v.as_str())
            {
                Some(s) => s,
                None => {
                    eprintln!("Error: no image data in response");
                    println!("{}", serde_json::to_string_pretty(&resp).unwrap());
                    return;
                }
            };

            let bytes = match base64::engine::general_purpose::STANDARD.decode(b64) {
                Ok(b) => b,
                Err(e) => {
                    eprintln!("Error: failed to decode base64: {e}");
                    return;
                }
            };

            let path = match output {
                Some(p) => p.to_string(),
                None => default_filename(),
            };

            match fs::write(&path, &bytes) {
                Ok(_) => println!("Saved {} ({} bytes)", path, bytes.len()),
                Err(e) => eprintln!("Error: failed to write file: {e}"),
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}

fn default_filename() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // UTC date/time from unix timestamp
    let days = secs / 86400;
    let day_secs = secs % 86400;
    let h = day_secs / 3600;
    let m = (day_secs % 3600) / 60;
    let s = day_secs % 60;

    // Days since 1970-01-01 to Y-M-D
    let (y, mo, d) = days_to_ymd(days);

    format!("photo_{y:04}-{mo:02}-{d:02}_{h:02}-{m:02}-{s:02}.jpg")
}

fn days_to_ymd(mut days: u64) -> (u64, u64, u64) {
    let mut y = 1970;
    loop {
        let year_days = if is_leap(y) { 366 } else { 365 };
        if days < year_days {
            break;
        }
        days -= year_days;
        y += 1;
    }
    let leap = is_leap(y);
    let month_days = [
        31,
        if leap { 29 } else { 28 },
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ];
    let mut mo = 0;
    for (i, &md) in month_days.iter().enumerate() {
        if days < md {
            mo = i as u64 + 1;
            break;
        }
        days -= md;
    }
    (y, mo, days + 1)
}

fn is_leap(y: u64) -> bool {
    y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
}
