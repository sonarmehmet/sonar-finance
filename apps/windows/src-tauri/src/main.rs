// Release'de ek konsol penceresi açılmasın (Windows).
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    sonar_finance_lib::run()
}
