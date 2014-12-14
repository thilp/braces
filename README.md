What for
========

This module splits a string into nested arrays (references) according to
the mirrored characters (such as braces and parentheses) it contains. For
instance, the string:

    "ab(cd)ef"

is transformed into the following structure:

    [
        "ab",
        [
            "(", "cd", ")"
        ],
        "ef"
    ]

The `t` directory contains more examples.

How
===

Quick start
-----------

This module does something so simple that it would be a shame to have to take
complicated steps to achieve it.
However, you can customize what mirrored characters it recognizes (and what
"mirrored" means), along with its verbosity level (you can make it scream at
unbalanced braces).
This "quick start" is just for the (majority of?) cases where the defaults are
fine for you.

1.  Load the module, along with its main function if you like:

    ```perl
    use Braces 'bsplit';
    ```

2.  Split:

    ```perl
    my $tree = bsplit($str);
    ```

More details, customizing
-------------------------

This module is composed of two main parts: the `bsplit` function and the
Braces::Registry class.

-   The `bsplit` function is exported by the `Braces` package and is the
    "public interface" of this module. Its signature in some typed Perl would
    be:

        bsplit(Str $s, Braces::Registry $r? --> ArrayRef)

    where:
    -   `$s` is the string to split,
    -   `$r` is a Braces::Registry instance (see below) – `?` denotes that
        this parameter is optional,
    -   what comes after `-->` denotes the function's return type.

-   The Braces::Registry class is used to change the way the `bsplit`
    function treats characters. By default, `bsplit` uses the Unicode database
    (with Unicode::UCD) to know what characters are mirrored and which closing
    character they match. In addition, the registry stores whether you want
    unbalanced braces reported on stderr (default: no). You can change these
    defaults by instantiating your own Braces::Registry and providing it to
    your `bsplit` calls:

    ```perl
    use Braces qw/ bsplit /;
    use Braces::Registry;

    my $registry = Braces::Registry->new(
        mapping   => { '(' => ')' },
        isOpening => \&some_predicate,
        isClosing => \&another_predicate,
        warnings  => 1,
    );

    my $tree = bsplit($str, $registry);
    ```

    The `mapping` hashref needs only to have opening characters as keys: it is
    never queried with closing characters.

    The `isOpening` and `isClosing` predicate functions are expected to accept
    one argument (the character) and return a boolean value (whether or not it
    is opening/closing according to your semantics).

I did not prove it, but the algorithm used in the `bsplit` function is most
likely linear in both time and space.
No regexes are involved, so no backtracking concerns.
All "hard" dependencies (Carp, Exporter and Unicode::UCD) are in core since a
loong time so this module is virtually without dependencies.
If List::Util or List::MoreUtils are installed, it will use them, but it
provides its own implementation in case they are not.
