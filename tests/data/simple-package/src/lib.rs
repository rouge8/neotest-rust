#[cfg(test)]
mod tests {
    #[test]
    fn math() {
        assert_eq!(1 + 1, 2);
    }

    #[test]
    /// same string
    fn same_string() {
        assert_eq!("robot".to_string(), String::from("robot"));
    }
}
