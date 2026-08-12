const std = @import("std");

pub const ScannerError = error{
    UnterminatedString,
    InvalidCharacter,
};

pub const ScannerFailure =
    ScannerError || std.mem.Allocator.Error;

pub const ParserError = error{
    InvalidSyntax,
    NestingTooDeep,
    NumberLiteralOutOfRange,
};

pub const ParserFailure =
    ParserError || std.mem.Allocator.Error;

pub const EnvironmentError = error{
    UndefinedVariable,
};

pub const RuntimeError = error{
    InvalidOperand,
    DivisionByZero,
    IntegerOverflow,
} || EnvironmentError;

pub const LanguageError =
    ScannerError ||
    ParserError ||
    RuntimeError;

pub const DevelopmentError = error{
    ExecutionDepthExceeded,
    FeatureNotImplemented,
};

pub const OutputError = std.Io.Writer.Error;

pub const InterpreterFailure =
    RuntimeError ||
    DevelopmentError ||
    std.mem.Allocator.Error ||
    OutputError;
