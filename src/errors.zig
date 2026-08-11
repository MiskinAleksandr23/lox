const std = @import("std");

pub const ParserError = error{
    InvalidSyntax,
    NumberLiteralOutOfRange,
};

pub const ParserFailure =
    ParserError || std.mem.Allocator.Error;

pub const ScannerError = error{
    UnterminatedString,
    InvalidCharacter,
};

pub const ScannerFailure = ScannerError || std.mem.Allocator.Error;

pub const EnvironmentError = error{
    UndefinedVariable,
};
pub const EnvironmentFailure = EnvironmentError || std.mem.Allocator.Error;

// FIXME: remove Unimplemented in future
pub const RuntimeError = error{
    InvalidOperand,
    DivisionByZero,
    Unimplemented,
} || EnvironmentFailure;

pub const RuntimeFailure = RuntimeError || std.mem.Allocator.Error;

pub const InterpreterFailure = RuntimeFailure;
