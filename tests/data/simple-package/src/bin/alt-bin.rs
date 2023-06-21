fn main() {
    println!("Hello, world!");
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_alt_bin() {
        assert_eq!(4 % 2, 0);
    }
}
