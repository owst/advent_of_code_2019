use std::io::{self, BufRead};

fn fuel_required(mass: u32) -> u32 {
    if mass < 6 {
        return 0;
    }

    (mass / 3) - 2
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
        .map(|m| fuel_required(m))
        .sum();

    println!("fuel_required: {}", total_fuel);
}
