use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;

pub struct RateLimiter {
    max_per_hour: u32,
    entries: Mutex<HashMap<String, (u32, Instant)>>,
}

impl RateLimiter {
    pub fn new(max_per_hour: u32) -> Self {
        Self {
            max_per_hour,
            entries: Mutex::new(HashMap::new()),
        }
    }

    /// Returns true if the request is allowed (under limit).
    pub fn check(&self, token: &str) -> bool {
        let mut entries = self.entries.lock().unwrap();
        let now = Instant::now();

        let entry = entries.entry(token.to_string()).or_insert((0, now));

        // Reset window if more than 1 hour has passed
        if now.duration_since(entry.1).as_secs() >= 3600 {
            entry.0 = 0;
            entry.1 = now;
        }

        if entry.0 >= self.max_per_hour {
            return false;
        }

        entry.0 += 1;
        true
    }
}
