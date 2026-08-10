// TODO: do we need all errors in ParseError?
pub const ParseError = error{
    InvalidSyntax,
    OutOfMemory,
    InvalidCharacter,
    Overflow,
};

// TODO: do we need all errors in ScanError?
pub const ScanError = error{
    OutOfMemory,
    UnterminatedString,
    InvalidCharacter,
};

pub const RuntimeError = error{
    InvalidOperand,
    DivisionByZero,
    OutOfMemory,
};
