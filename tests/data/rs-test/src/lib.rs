#[cfg(test)]
mod tests {
    use rstest::*;

    #[fixture]
    fn bar() -> i32 {
        42
    }
    #[rstest]
    fn fixture_injected(bar: i32) {
        assert_eq!(42, bar)
    }

    #[fixture]
    fn long_and_boring_descriptive_name() -> i32 {
        42
    }
    #[rstest]
    fn fixture_rename(#[from(long_and_boring_descriptive_name)] short: i32) {
        assert_eq!(42, short)
    }

    #[rstest]
    #[case(0)]
    #[case(1)]
    #[case(5)]
    // random comment in between
    #[case(42)]
    fn parameterized(#[case] x: u64) {
        assert!(x < 10)
    }

    #[rstest]
    #[case(0)]
    // random comment in between
    #[case(1)]
    #[case(5)]
    #[case(42)]
    #[tokio::test]
    async fn parameterized_tokio(#[case] x: u64) {
        assert!(x < 10)
    }

    #[rstest]
    #[case(0)]
    // random comment in between
    #[case(1)]
    #[case(5)]
    #[case(42)]
    #[async_std::test]
    async fn parameterized_async_std(#[case] x: u64) {
        assert!(x < 10)
    }

    // Only supported by `parameterized_test_discovery="cargo"` mode right now. Too complex for a plain tree sitter =(
    #[rstest]
    fn fifth(#[values("a", "bb", "ccc")] word: &str, #[values(1, 2, 3)] has_chars: usize) {
        assert_eq!(word.chars().count(), has_chars)
    }
}
