#[cfg(test)]
mod tests {
    use test_case::test_case;

    #[test_case(0 ; "")]
    #[test_case(1 ; "one")]
    #[test_case(2 ; "name with spaces")]
    // random comment in between
    #[test_case(3 ; "MixEd-CaSe")]
    #[test_case(4 ; "sp3(|a/-(ar5")]
    fn first(x: u64) {
        assert!(x < 4);
    }

    #[test_case(true ; "yes")]
    // random comment in between
    #[test_case(false ; "no")]
    #[tokio::test]
    async fn second(y: bool) {
        assert!(y)
    }

    #[test_case(true ; "yes")]
    // random comment in between
    #[test_case(false ; "no")]
    #[async_std::test]
    async fn third(y: bool) {
        assert!(y)
    }
}
