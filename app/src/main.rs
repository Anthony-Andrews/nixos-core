fn main() {
    loop {
        println!("app {} running", env!("CARGO_PKG_VERSION"));
        std::thread::sleep(std::time::Duration::from_secs(60));
    }
}
