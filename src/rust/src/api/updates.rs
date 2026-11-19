#[derive(Debug, Clone)]
pub struct AppUpdateInfoDto {
    pub latest_version: String,
    pub changelog: String,
    pub url: String,
    pub has_update: bool,
}

fn is_newer_version(current: &str, latest: &str) -> bool {
    let clean = |v: &str| -> String {
        let mut cleaned = v.trim().to_lowercase();
        // Android releases in the personal fork use an isolated tag prefix
        // so they never trigger the desktop multi-platform publisher.
        if let Some(version) = cleaned.strip_prefix("android-") {
            cleaned = version.to_string();
        }
        if cleaned.starts_with('v') {
            cleaned.remove(0);
        }
        if let Some(pos) = cleaned.find('+') {
            cleaned.truncate(pos);
        }
        cleaned
    };

    let cur_clean = clean(current);
    let lat_clean = clean(latest);

    let cur_parts: Vec<i32> = cur_clean
        .split('.')
        .map(|s| s.parse().unwrap_or(0))
        .collect();
    let lat_parts: Vec<i32> = lat_clean
        .split('.')
        .map(|s| s.parse().unwrap_or(0))
        .collect();

    let max_len = std::cmp::max(cur_parts.len(), lat_parts.len());
    for i in 0..max_len {
        let cur_val = *cur_parts.get(i).unwrap_or(&0);
        let lat_val = *lat_parts.get(i).unwrap_or(&0);
        if lat_val > cur_val {
            return true;
        }
        if lat_val < cur_val {
            return false;
        }
    }
    false
}

pub async fn check_for_updates() -> Option<AppUpdateInfoDto> {
    let client = match reqwest::Client::builder().user_agent("yayma-app").build() {
        Ok(client) => client,
        Err(e) => {
            tracing::warn!(error = %e, "update_check_client_failed");
            return None;
        }
    };

    // Keep desktop builds on the upstream release channel. Android builds
    // must follow the user's fork, otherwise the next upstream APK would
    // replace the custom Android UI and features.
    let repository = if cfg!(target_os = "android") {
        "phantom-lancer/YAYMA"
    } else {
        "DarkPlayOff/YAYMA"
    };
    let releases_url = format!(
        "https://api.github.com/repos/{repository}/releases/latest"
    );
    let res = match client
        .get(releases_url)
        .header("Accept", "application/vnd.github.v3+json")
        .send()
        .await
    {
        Ok(res) => res,
        Err(e) => {
            tracing::warn!(error = %e, "update_check_request_failed");
            return None;
        }
    };

    if !res.status().is_success() {
        tracing::warn!(status = %res.status(), "update_check_request_rejected");
        return None;
    }

    #[derive(serde::Deserialize)]
    struct GithubRelease {
        tag_name: String,
        body: Option<String>,
        html_url: String,
    }

    let release: GithubRelease = match res.json().await {
        Ok(release) => release,
        Err(e) => {
            tracing::warn!(error = %e, "update_check_parse_failed");
            return None;
        }
    };
    let current_version = crate::api::simple::get_app_version();
    let has_update = is_newer_version(&current_version, &release.tag_name);

    if has_update {
        tracing::info!(version = %release.tag_name, "update_available");
    }

    Some(AppUpdateInfoDto {
        latest_version: release.tag_name,
        changelog: release.body.unwrap_or_default(),
        url: release.html_url,
        has_update,
    })
}
