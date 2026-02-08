use crate::config::{ApnsConfig, Config};

pub async fn show_config() {
    match Config::load() {
        Ok(config) => {
            println!("Server URL: {}", config.server.url);
            println!("API Key:    {}", config.server.api_key);
            println!("Port:       {}", config.server.port);
            println!("Bind:       {}", config.server.bind);

            if let Some(apns) = &config.apns {
                println!();
                println!("[APNs]");
                println!("Key Path:   {}", apns.key_path);
                println!("Key ID:     {}", apns.key_id);
                println!("Team ID:    {}", apns.team_id);
                println!("Bundle ID:  {}", apns.bundle_id);
                println!("Sandbox:    {}", apns.sandbox);
            }
        }
        Err(e) => eprintln!("Error: {e}"),
    }
}

pub async fn set_config(key: &str, value: &str) {
    let mut config = match Config::load() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Error: {e}");
            return;
        }
    };

    match key {
        "server" | "url" => config.server.url = value.to_string(),
        "api_key" | "token" => config.server.api_key = value.to_string(),
        "port" => {
            match value.parse::<u16>() {
                Ok(p) => config.server.port = p,
                Err(_) => {
                    eprintln!("Invalid port number");
                    return;
                }
            }
        }
        "bind" => config.server.bind = value.to_string(),
        "apns.key_path" => apns_mut(&mut config).key_path = value.to_string(),
        "apns.key_id" => apns_mut(&mut config).key_id = value.to_string(),
        "apns.team_id" => apns_mut(&mut config).team_id = value.to_string(),
        "apns.bundle_id" => apns_mut(&mut config).bundle_id = value.to_string(),
        "apns.sandbox" => {
            match value.parse::<bool>() {
                Ok(b) => apns_mut(&mut config).sandbox = b,
                Err(_) => {
                    eprintln!("Invalid boolean (use true/false)");
                    return;
                }
            }
        }
        _ => {
            eprintln!("Unknown config key: {key}");
            eprintln!("Available: server, api_key, port, bind");
            eprintln!("  APNs:   apns.key_path, apns.key_id, apns.team_id, apns.bundle_id, apns.sandbox");
            return;
        }
    }

    match config.save() {
        Ok(()) => println!("Config updated: {key} = {value}"),
        Err(e) => eprintln!("Error saving config: {e}"),
    }
}

fn apns_mut(config: &mut Config) -> &mut ApnsConfig {
    config.apns.get_or_insert(ApnsConfig {
        key_path: String::new(),
        key_id: String::new(),
        team_id: String::new(),
        bundle_id: String::new(),
        sandbox: false,
    })
}
