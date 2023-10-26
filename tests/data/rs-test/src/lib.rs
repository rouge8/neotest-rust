#[cfg(test)]
mod tests {
    use rstest::*;
    use std::{ffi::OsStr, path::PathBuf, time::Duration};

    #[rstest]
    #[timeout(Duration::from_millis(10))]
    fn timeout() {
        std::thread::sleep(Duration::from_millis(15));
        assert!(true)
    }

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

    struct User(String, u8);
    #[fixture]
    fn user(#[default("Alice")] name: impl AsRef<str>, #[default(22)] age: u8) -> User {
        User(name.as_ref().to_owned(), age)
    }
    #[rstest]
    fn fixture_partial_injection(#[with("Bob")] user: User) {
        assert_eq!("Bob", user.0)
    }

    #[fixture]
    async fn magic() -> i32 {
        42
    }
    #[rstest]
    #[tokio::test]
    async fn fixture_async(#[future] magic: i32) {
        assert_eq!(magic.await, 42)
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
    #[case::one(1)]
    #[case::two(2)]
    #[case::ten(10)]
    fn parameterized_with_descriptions(#[case] x: u64) {
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

    #[rstest]
    #[case::even(async { 2 })]
    // random comment in between
    #[case::odd(async { 3 })]
    #[tokio::test]
    async fn parameterized_async_parameter(
        #[future]
        #[case]
        n: u32,
    ) {
        let n = n.await;
        assert!(n % 2 == 0, "{n} not even");
    }

    #[rstest]
    #[case::pass(Duration::from_millis(1))]
    #[timeout(Duration::from_millis(10))]
    #[case::fail(Duration::from_millis(25))]
    #[timeout(Duration::from_millis(20))]
    fn parameterized_timeout(#[case] sleepy: Duration) {
        std::thread::sleep(sleepy);
        assert!(true)
    }

    #[rstest]
    #[case::pass(Duration::from_millis(1), 4)]
    #[timeout(Duration::from_millis(10))]
    #[case::fail_timeout(Duration::from_millis(60), 4)]
    #[case::fail_value(Duration::from_millis(1), 5)]
    #[timeout(Duration::from_millis(100))]
    async fn parameterized_async_timeout(#[case] delay: Duration, #[case] expected: u32) {
        async fn delayed_sum(a: u32, b: u32, delay: Duration) -> u32 {
            async_std::task::sleep(delay).await;
            a + b
        }
        assert_eq!(expected, delayed_sum(2, 2, delay).await);
    }

    // The following are only supported by `parameterized_test_discovery="cargo"` mode right now. Too complex for a plain tree sitter =(
    #[rstest]
    fn combinations(#[values("a", "bb", "ccc")] word: &str, #[values(1, 2, 3)] has_chars: usize) {
        assert_eq!(word.chars().count(), has_chars)
    }

    #[rstest]
    fn files(#[files("**/*.txt")] file: PathBuf) {
        assert_eq!(file.extension(), Some(OsStr::new("txt")))
    }
}
