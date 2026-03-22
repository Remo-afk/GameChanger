use iced::{
    widget::{button, column, container, row, text, vertical_space, progress_bar, horizontal_space, tooltip, pick_list, text_input},
    Alignment, Application, Command, Element, Length, Settings, Theme,
    window, Subscription, time, Color, Background, Font,
};
use std::process::Command as SysCommand;
use std::sync::Arc;
use chrono::Local;
use tokio::sync::Mutex;
use std::time::Duration;
use serde::{Serialize, Deserialize};
use std::fs;
use dirs;

// ========== KONFIGURATION ==========
const RGB_CORE: &str = "/usr/local/bin/logitech_rgb";
const BATTERY_PATH: &str = "/sys/class/power_supply/";
const UPDATE_INTERVAL: Duration = Duration::from_secs(30);
const FADE_STEPS: u8 = 15;
const PROFILES_DIR: &str = ".config/gamechanger/profiles";

// ========== PROFIL-STRUKTUR ==========
#[derive(Debug, Clone, Serialize, Deserialize)]
struct RGBProfile {
    name: String,
    colors: Vec<ColorPoint>,
    speed: u8, // Fading speed (ms)
    loop_mode: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ColorPoint {
    r: u8,
    g: u8,
    b: u8,
    duration_ms: u32,
}

impl Default for RGBProfile {
    fn default() -> Self {
        Self {
            name: "Default".to_string(),
            colors: vec![
                ColorPoint { r: 255, g: 0, b: 0, duration_ms: 1000 },
                ColorPoint { r: 0, g: 255, b: 0, duration_ms: 1000 },
                ColorPoint { r: 0, g: 0, b: 255, duration_ms: 1000 },
            ],
            speed: 30,
            loop_mode: false,
        }
    }
}

// ========== DATENSTRUKTUREN ==========
#[derive(Debug, Clone)]
struct BatteryDevice {
    name: String,
    icon: char,
    level: u8,
    charging: bool,
}

#[derive(Debug, Clone)]
struct AppState {
    devices: Vec<BatteryDevice>,
    rgb_status: String,
    last_update: String,
    current_color: (u8, u8, u8),
    is_fading: bool,
    profiles: Vec<RGBProfile>,
    current_profile: String,
    profile_editor_open: bool,
    new_profile_name: String,
    selected_color: (u8, u8, u8),
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            devices: Vec::new(),
            rgb_status: "Bereit".to_string(),
            last_update: "--:--:--".to_string(),
            current_color: (0, 255, 255),
            is_fading: false,
            profiles: vec![RGBProfile::default()],
            current_profile: "Default".to_string(),
            profile_editor_open: false,
            new_profile_name: String::new(),
            selected_color: (255, 0, 0),
        }
    }
}

// ========== MAIN ==========
pub fn main() -> iced::Result {
    GameChangerUI::run(Settings {
        window: window::Settings {
            size: iced::Size::new(560.0, 720.0),
            position: window::Position::Centered,
            decorations: false,
            transparent: true,
            ..window::Settings::default()
        },
        ..Settings::default()
    })
}

struct GameChangerUI {
    state: Arc<Mutex<AppState>>,
}

#[derive(Debug, Clone)]
enum Message {
    // Basic
    Refresh,
    SetColor(u8, u8, u8),
    FadeTo(u8, u8, u8),
    Rescan,
    UpdateData(Vec<BatteryDevice>),
    UpdateRgbStatus(String),
    
    // Profile
    LoadProfile(String),
    SaveProfile,
    DeleteProfile(String),
    ToggleProfileEditor,
    UpdateNewProfileName(String),
    AddColorToProfile,
    RemoveColorFromProfile(usize),
    UpdateProfileColor(usize, u8, u8, u8),
    SetProfileSpeed(u8),
    ToggleProfileLoop,
    
    // UI
    ToggleDrag,
    Close,
    Noop,
}

impl Application for GameChangerUI {
    type Executor = iced::executor::Default;
    type Message = Message;
    type Theme = Theme;
    type Flags = ();

    fn new(_flags: ()) -> (Self, Command<Message>) {
        let state = Arc::new(Mutex::new(AppState::default()));
        
        // Lade gespeicherte Profile
        let state_clone = state.clone();
        let load_cmd = Command::perform(
            async move {
                load_profiles().await
            },
            |profiles| {
                Message::UpdateRgbStatus(format!("{} Profile geladen", profiles.len()))
            }
        );
        
        (
            GameChangerUI { state },
            Command::batch(vec![
                Command::perform(async { get_battery_devices().await }, Message::UpdateData),
                load_cmd,
            ])
        )
    }

    fn title(&self) -> String { String::from("🎮 GameChanger v5.3") }

    fn subscription(&self) -> Subscription<Message> {
        time::every(UPDATE_INTERVAL).map(|_| Message::Refresh)
    }

    fn update(&mut self, message: Message) -> Command<Message> {
        match message {
            Message::Refresh => {
                return Command::perform(async { get_battery_devices().await }, Message::UpdateData);
            }
            Message::UpdateData(devices) => {
                let state_clone = self.state.clone();
                return Command::perform(async move {
                    let mut state = state_clone.lock().await;
                    state.devices = devices;
                    state.last_update = Local::now().format("%H:%M:%S").to_string();
                }, |_| Message::Noop);
            }
            Message::SetColor(r, g, b) => {
                let _ = SysCommand::new(RGB_CORE).args([r.to_string(), g.to_string(), b.to_string()]).output();
                let state_clone = self.state.clone();
                return Command::perform(async move {
                    let mut state = state_clone.lock().await;
                    state.current_color = (r, g, b);
                    state.rgb_status = format!("✅ RGB: {},{},{}", r, g, b);
                }, |_| Message::Noop);
            }
            Message::FadeTo(r, g, b) => {
                let state_clone = self.state.clone();
                return Command::perform(async move {
                    let mut state = state_clone.lock().await;
                    if state.is_fading { return; }
                    state.is_fading = true;
                    let (start_r, start_g, start_b) = state.current_color;
                    drop(state);

                    for step in 0..=FADE_STEPS {
                        let t = step as f32 / FADE_STEPS as f32;
                        let nr = (start_r as f32 + (r as f32 - start_r as f32) * t) as u8;
                        let ng = (start_g as f32 + (g as f32 - start_g as f32) * t) as u8;
                        let nb = (start_b as f32 + (b as f32 - start_b as f32) * t) as u8;
                        
                        let _ = SysCommand::new(RGB_CORE).args([nr.to_string(), ng.to_string(), nb.to_string()]).output();
                        tokio::time::sleep(Duration::from_millis(40)).await;
                    }

                    let mut state = state_clone.lock().await;
                    state.current_color = (r, g, b);
                    state.is_fading = false;
                    state.rgb_status = format!("✅ Fade fertig: {},{},{}", r, g, b);
                }, |_| Message::Noop);
            }
            Message::LoadProfile(name) => {
                let state_clone = self.state.clone();
                return Command::perform(
                    async move {
                        if let Some(profile) = load_profile_by_name(&name).await {
                            // Fade durch das Profil
                            for color in profile.colors {
                                let _ = SysCommand::new(RGB_CORE)
                                    .args([color.r.to_string(), color.g.to_string(), color.b.to_string()])
                                    .output();
                                tokio::time::sleep(Duration::from_millis(color.duration_ms as u64)).await;
                            }
                            Some(profile)
                        } else {
                            None
                        }
                    },
                    move |profile| {
                        if let Some(p) = profile {
                            Message::UpdateRgbStatus(format!("✅ Profil '{}' geladen", p.name))
                        } else {
                            Message::UpdateRgbStatus("❌ Profil nicht gefunden".to_string())
                        }
                    }
                );
            }
            Message::SaveProfile => {
                let state_clone = self.state.clone();
                return Command::perform(
                    async move {
                        let mut state = state_clone.lock().await;
                        if state.new_profile_name.is_empty() {
                            return "❌ Name erforderlich".to_string();
                        }
                        let profile = RGBProfile {
                            name: state.new_profile_name.clone(),
                            colors: vec![
                                ColorPoint { r: state.selected_color.0, g: state.selected_color.1, b: state.selected_color.2, duration_ms: 1000 }
                            ],
                            speed: 30,
                            loop_mode: false,
                        };
                        save_profile(&profile).await;
                        state.profiles.push(profile);
                        state.new_profile_name.clear();
                        state.profile_editor_open = false;
                        format!("✅ Profil '{}' gespeichert", state.new_profile_name)
                    },
                    Message::UpdateRgbStatus
                );
            }
            Message::DeleteProfile(name) => {
                let state_clone = self.state.clone();
                return Command::perform(
                    async move {
                        delete_profile(&name).await;
                        let mut state = state_clone.lock().await;
                        state.profiles.retain(|p| p.name != name);
                        format!("🗑️ Profil '{}' gelöscht", name)
                    },
                    Message::UpdateRgbStatus
                );
            }
            Message::Rescan => {
                let _ = SysCommand::new(RGB_CORE).arg("rescan").output();
                return Command::perform(async { get_battery_devices().await }, Message::UpdateData);
            }
            Message::ToggleDrag => return window::drag(window::Id::MAIN),
            Message::Close => return window::close(window::Id::MAIN),
            Message::ToggleProfileEditor => {
                let state_clone = self.state.clone();
                return Command::perform(async move {
                    let mut state = state_clone.lock().await;
                    state.profile_editor_open = !state.profile_editor_open;
                }, |_| Message::Noop);
            }
            Message::UpdateNewProfileName(name) => {
                let state_clone = self.state.clone();
                return Command::perform(async move {
                    let mut state = state_clone.lock().await;
                    state.new_profile_name = name;
                }, |_| Message::Noop);
            }
            Message::UpdateRgbStatus(status) => {
                let state_clone = self.state.clone();
                return Command::perform(async move {
                    let mut state = state_clone.lock().await;
                    state.rgb_status = status;
                }, |_| Message::Noop);
            }
            _ => {}
        }
        Command::none()
    }

    fn view(&self) -> Element<Message> {
        let (devices, status, time, color, fading, profiles, current_profile, editor_open, new_name, selected_color) = 
            if let Ok(s) = self.state.try_lock() {
                (s.devices.clone(), s.rgb_status.clone(), s.last_update.clone(), 
                 s.current_color, s.is_fading, s.profiles.clone(), s.current_profile.clone(),
                 s.profile_editor_open, s.new_profile_name.clone(), s.selected_color)
            } else {
                (vec![], "...".to_string(), "--:--".to_string(), (0,0,0), false, 
                 vec![], "Default".to_string(), false, String::new(), (255,0,0))
            };
        
        // Farbvorschau
        let color_preview = container(horizontal_space())
            .width(40).height(20)
            .style(move |_| container::Appearance {
                background: Some(Background::Color(Color::from_rgb(
                    color.0 as f32/255.0, color.1 as f32/255.0, color.2 as f32/255.0
                ))),
                border_radius: 5.0.into(),
                border_width: 1.0,
                border_color: Color::WHITE,
                ..Default::default()
            });
        
        // Profile Dropdown
        let profile_picker = pick_list(
            profiles.iter().map(|p| p.name.clone()).collect::<Vec<_>>(),
            Some(current_profile),
            Message::LoadProfile
        ).width(Length::Fixed(150.0));
        
        let content = column![
            // Header
            row![
                button(text("🎮 GameChanger").size(22).style(Color::from_rgb(0.0, 1.0, 1.0)))
                    .on_press(Message::ToggleDrag)
                    .style(iced::theme::Button::Text),
                horizontal_space(),
                color_preview,
                horizontal_space(),
                button("✕").on_press(Message::Close).style(iced::theme::Button::Destructive),
            ].align_items(Alignment::Center),

            text(status).size(12).style(Color::from_rgb(0.5, 0.7, 0.5)),

            // Farb-Buttons
            row![
                color_button("🔴", 255, 0, 0, "Rot"),
                color_button("🟢", 0, 255, 0, "Grün"),
                color_button("🔵", 0, 0, 255, "Blau"),
                color_button("🟡", 255, 255, 0, "Gelb"),
                color_button("⚪", 255, 255, 255, "Weiß"),
                color_button("🌑", 0, 0, 0, "Aus"),
            ].spacing(8),

            // Profile-Zeile
            row![
                profile_picker,
                button("💾 Speichern").on_press(Message::ToggleProfileEditor).padding(6),
                button("🗑️ Löschen").on_press(Message::DeleteProfile(current_profile)).padding(6),
                button("🔄 Rescan").on_press(Message::Rescan).padding(6),
            ].spacing(8),

            // Profil-Editor
            if editor_open {
                column![
                    text_input("Profilname", &new_name).on_input(Message::UpdateNewProfileName).padding(8),
                    row![
                        color_button("🔴", 255, 0, 0, "Rot"),
                        color_button("🟢", 0, 255, 0, "Grün"),
                        color_button("🔵", 0, 0, 255, "Blau"),
                    ].spacing(8),
                    button("💾 Profil speichern").on_press(Message::SaveProfile).padding(8),
                ].spacing(8).into()
            } else {
                vertical_space(0).into()
            },

            vertical_space(10),
            text("🔋 BATTERY STATUS").size(14).style(Color::from_rgb(0.6, 0.6, 0.6)),

            column(devices.iter().map(|d| {
                row![
                    text(format!("{} {}", d.icon, d.name)).width(140),
                    progress_bar(0.0..=100.0, d.level as f32).width(Length::Fill),
                    text(format!("{}%", d.level)).width(40),
                    text(if d.charging { "⚡" } else { "" }).width(20),
                ].spacing(10).align_items(Alignment::Center).into()
            }).collect::<Vec<_>>()).spacing(8),

            vertical_space(Length::Fill),
            row![
                text(format!("📅 {}", time)).size(10),
                horizontal_space(),
                text(if fading { "🎨 Fading..." } else { "🦀 Rust v5.3" }).size(10)
            ]
        ].spacing(12).padding(20);
        
        container(content)
            .style(iced::theme::Container::Custom(Box::new(CustomStyle)))
            .into()
    }

    fn theme(&self) -> Self::Theme { Theme::Dark }
}

// ========== HELFER-FUNKTIONEN ==========

async fn get_battery_devices() -> Vec<BatteryDevice> {
    let mut devices = Vec::new();
    
    if let Ok(entries) = std::fs::read_dir(BATTERY_PATH) {
        for entry in entries.flatten() {
            let path = entry.path();
            let name = path.file_name().unwrap().to_string_lossy();
            
            if name.starts_with("AC") || name.starts_with("ADP") { continue; }
            
            let cap_path = path.join("capacity");
            if cap_path.exists() {
                if let Ok(level_str) = std::fs::read_to_string(cap_path) {
                    if let Ok(level) = level_str.trim().parse::<u8>() {
                        let status_path = path.join("status");
                        let charging = if status_path.exists() {
                            if let Ok(status) = std::fs::read_to_string(status_path) {
                                status.to_lowercase().contains("charging")
                            } else { false }
                        } else { false };
                        
                        let (icon, name_str) = if name.contains("hidpp_battery_0") {
                            ('🖱️', "Gaming Mouse".to_string())
                        } else if name.contains("hidpp_battery_1") {
                            ('⌨️', "Gaming Keyboard".to_string())
                        } else if name.contains("ps") || name.contains("controller") {
                            ('🎮', "Gaming Controller".to_string())
                        } else {
                            ('🔋', name.to_string())
                        };
                        
                        devices.push(BatteryDevice { name: name_str, icon, level, charging });
                    }
                }
            }
        }
    }
    
    // Headset prüfen
    if let Ok(output) = tokio::process::Command::new("lsusb")
        .arg("-d").arg("10d6:4801").output().await
    {
        if !output.stdout.is_empty() {
            devices.push(BatteryDevice {
                name: "Gaming Headset".to_string(),
                icon: '🎧',
                level: 0,
                charging: false,
            });
        }
    }
    
    devices
}

async fn load_profiles() -> Vec<RGBProfile> {
    let mut profiles = vec![RGBProfile::default()];
    let config_dir = dirs::config_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
    let profile_dir = config_dir.join(PROFILES_DIR);
    
    if let Ok(entries) = fs::read_dir(profile_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("json") {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(profile) = serde_json::from_str::<RGBProfile>(&content) {
                        profiles.push(profile);
                    }
                }
            }
        }
    }
    profiles
}

async fn load_profile_by_name(name: &str) -> Option<RGBProfile> {
    let config_dir = dirs::config_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
    let profile_path = config_dir.join(PROFILES_DIR).join(format!("{}.json", name));
    fs::read_to_string(profile_path).ok().and_then(|c| serde_json::from_str(&c).ok())
}

async fn save_profile(profile: &RGBProfile) {
    let config_dir = dirs::config_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
    let profile_dir = config_dir.join(PROFILES_DIR);
    let _ = fs::create_dir_all(&profile_dir);
    let profile_path = profile_dir.join(format!("{}.json", profile.name));
    if let Ok(content) = serde_json::to_string_pretty(profile) {
        let _ = fs::write(profile_path, content);
    }
}

async fn delete_profile(name: &str) {
    let config_dir = dirs::config_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
    let profile_path = config_dir.join(PROFILES_DIR).join(format!("{}.json", name));
    let _ = fs::remove_file(profile_path);
}

fn color_button(icon: &str, r: u8, g: u8, b: u8, tt: &str) -> Element<'static, Message> {
    tooltip(
        button(text(icon).size(24)).on_press(Message::SetColor(r, g, b)).width(55).padding(8),
        tt,
        iced::widget::tooltip::Position::Bottom
    ).into()
}

struct CustomStyle;
impl container::StyleSheet for CustomStyle {
    type Style = Theme;
    fn appearance(&self, _style: &Self::Style) -> container::Appearance {
        container::Appearance {
            background: Some(Background::Color(Color::from_rgba(0.05, 0.05, 0.08, 0.95))),
            border_radius: 15.0.into(),
            border_width: 1.0,
            border_color: Color::from_rgb(0.2, 0.2, 0.3),
            ..Default::default()
        }
    }
}
