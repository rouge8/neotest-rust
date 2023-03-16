fn main() {
    println!("Hello, world!");
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_it() {
        assert_eq!(true, true);
    }
}
