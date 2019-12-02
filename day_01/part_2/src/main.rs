use std::io::{self, BufRead};

/// ```
/// assert_eq!(fuel_required(12), 2);
/// assert_eq!(fuel_required(14), 2);
/// assert_eq!(fuel_required(1969), 654);
/// assert_eq!(fuel_required(100756), 33583);
/// ```
fn fuel_required(mass: u32) -> u32 {
    if mass < 6 {
        return 0;
    }

    (mass / 3) - 2
}

/// ```
/// assert_eq!(total_fuel_required(14), 2);
/// assert_eq!(total_fuel_required(1969), 966);
/// assert_eq!(total_fuel_required(100756), 50346);
/// ```
fn total_fuel_required(mass: u32) -> u32 {
    let fuel = fuel_required(mass);

    let fuel_fuel = if fuel > 0 { total_fuel_required(fuel) } else { 0 };

    fuel + fuel_fuel
}

fn collect_masses() -> Vec<u32> {
    io::stdin()
        .lock()
        .lines()
        .map(|l| l.unwrap().trim().parse().expect("couldn't parse"))
        .collect()
}

fn main() {
    let total_fuel:u32 = collect_masses()
        .into_iter()
        .map(|m| total_fuel_required(m))
        .sum();

    println!("fuel_required: {}", total_fuel);
}
