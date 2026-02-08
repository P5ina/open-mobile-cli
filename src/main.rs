use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "omcli", version, about = "Remote mobile device control")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the relay server
    Serve {
        #[arg(long, default_value = "7333")]
        port: u16,
        #[arg(long, default_value = "127.0.0.1")]
        bind: String,
    },
    /// Alarm commands
    Alarm {
        #[command(subcommand)]
        action: AlarmAction,
    },
    /// Send notification to device
    Notify {
        /// Message text
        message: String,
        /// Priority: low, normal, critical
        #[arg(long, default_value = "normal")]
        priority: String,
    },
    /// Get device location
    Locate {
        #[arg(long)]
        device: Option<String>,
    },
    /// Server and device status
    Status,
    /// Pair a device using the 6-digit code
    Pair {
        /// 6-digit pairing code from device
        code: String,
    },
    /// Activate sleep/standby mode (keeps screen on for alarm)
    Sleep {
        /// Target device ID
        #[arg(long)]
        device: Option<String>,
    },
    /// Deactivate sleep mode
    Wake {
        /// Target device ID
        #[arg(long)]
        device: Option<String>,
    },
    /// List paired devices
    Devices,
    /// View or update configuration
    Config {
        #[command(subcommand)]
        action: Option<ConfigAction>,
    },
}

#[derive(Subcommand)]
enum AlarmAction {
    /// Start alarm on device
    Start {
        /// Sound: default, loud, hell
        #[arg(long, default_value = "default")]
        sound: String,
        /// Optional message to display
        #[arg(long)]
        message: Option<String>,
        /// Target device ID
        #[arg(long)]
        device: Option<String>,
    },
    /// Stop alarm on device
    Stop {
        /// Target device ID
        #[arg(long)]
        device: Option<String>,
    },
}

#[derive(Subcommand)]
enum ConfigAction {
    /// Set a config value (keys: server, api_key, port, bind)
    Set {
        key: String,
        value: String,
    },
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Serve { port, bind } => {
            omcli::server::serve(port, bind).await;
        }
        Commands::Alarm { action } => match action {
            AlarmAction::Start {
                sound,
                message,
                device,
            } => {
                omcli::cli::alarm_start(&sound, message.as_deref(), device.as_deref()).await;
            }
            AlarmAction::Stop { device } => {
                omcli::cli::alarm_stop(device.as_deref()).await;
            }
        },
        Commands::Notify { message, priority } => {
            omcli::cli::send_notification(&message, &priority).await;
        }
        Commands::Locate { device } => {
            omcli::cli::locate(device.as_deref()).await;
        }
        Commands::Sleep { device } => {
            omcli::cli::sleep_start(device.as_deref()).await;
        }
        Commands::Wake { device } => {
            omcli::cli::sleep_stop(device.as_deref()).await;
        }
        Commands::Status => {
            omcli::cli::server_status().await;
        }
        Commands::Pair { code } => {
            omcli::cli::pair(&code).await;
        }
        Commands::Devices => {
            omcli::cli::list_devices().await;
        }
        Commands::Config { action } => match action {
            Some(ConfigAction::Set { key, value }) => {
                omcli::cli::set_config(&key, &value).await;
            }
            None => {
                omcli::cli::show_config().await;
            }
        },
    }
}
