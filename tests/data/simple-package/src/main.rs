mod mymod;
mod parent;
mod other_mod;

fn main() {
    println!("Hello, world!");
}

#[cfg(test)]
mod tests {
    #[test]
    fn basic_math() {
        assert_eq!(1 + 1, 2);
    }

    #[test]
    fn failed_math() {
        assert_eq!(1 + 1, 3);
    }

    mod nested {
        #[test]
        fn nested_math() {
            assert_eq!(1 + 2, 3);
        }
    }
}
