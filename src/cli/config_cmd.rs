use crate::config::Config;

pub async fn show_config() {
    match Config::load() {
        Ok(config) => {
            println!("Server URL: {}", config.server.url);
            println!("API Key:    {}", config.server.api_key);
            println!("Port:       {}", config.server.port);
            println!("Bind:       {}", config.server.bind);
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
        _ => {
            eprintln!("Unknown config key: {key}");
            eprintln!("Available: server, api_key, port, bind");
            return;
        }
    }

    match config.save() {
        Ok(()) => println!("Config updated: {key} = {value}"),
        Err(e) => eprintln!("Error saving config: {e}"),
    }
}
