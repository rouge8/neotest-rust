#[test]
fn top_level_math() {
    assert_eq!(1 + 1, 2);
}

mod nested {
    #[test]
    fn nested_math() {
        assert_eq!(1 + 2, 3);
    }

    mod extra_nested {
        #[test]
        fn extra_nested_math() {
            assert_eq!(2 + 2, 4);
        }
    }
}
