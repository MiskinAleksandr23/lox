const std = @import("std");

pub const ParseError = error{
    InvalidSyntax,
    NumberLiteralOutOfRange,
};

pub const ParserFailure =
    ParseError || std.mem.Allocator.Error;

pub const ScanError = error{
    UnterminatedString,
    InvalidCharacter,
};

pub const ScannerError = ScanError || std.mem.Allocator.Error;

pub const RuntimeError = error{
    InvalidOperand,
    UndefinedVariable,
    NotCallable,
    ArityMismatch,
    InvalidPropertyReceiver,
    UndefinedProperty,
    DivisionByZero,
    IntegerOverflow,
    Unimplemented, // Remove in future,
    UnknownIdentifier,
};

pub const InterpreterFailure =
    RuntimeError ||
    std.mem.Allocator.Error;
