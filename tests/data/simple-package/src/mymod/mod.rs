mod foo;
mod multiple_macros;

#[cfg(test)]
mod tests {
    #[test]
    fn math() {
        assert_eq!(1 + 1, 2);
    }
}
