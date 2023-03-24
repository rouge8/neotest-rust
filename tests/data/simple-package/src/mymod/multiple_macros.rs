#[test]
#[should_panic]
fn should_panic_last() {
    assert_eq!(1, 1);
}

#[should_panic]
#[test]
fn should_panic_first() {
    assert_eq!(1, 1);
}

fn no_macros() {
    assert_eq!(2, 1);
}
