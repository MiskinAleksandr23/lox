const Writer = @import("std").Io.Writer;
const LanguageError = @import("errors.zig").LanguageError;

pub const Stage = enum {
    scanner,
    parser,
    runtime,

    fn label(self: Stage) []const u8 {
        return switch (self) {
            .scanner => "Scan error",
            .parser => "Parse error",
            .runtime => "Runtime error",
        };
    }
};

pub const Diagnostic = struct {
    stage: Stage,
    kind: LanguageError,
    line: usize,
    lexeme: []const u8,
    at_end: bool = false,
    message: []const u8,

    pub fn print(self: Diagnostic, output: *Writer) Writer.Error!void {
        if (self.at_end) {
            try output.print(
                "{s} [line {d}] at end: {s} ({s})\n",
                .{ self.stage.label(), self.line, self.message, @errorName(self.kind) },
            );
        } else if (self.lexeme.len != 0) {
            try output.print(
                "{s} [line {d}] at '{s}': {s} ({s})\n",
                .{ self.stage.label(), self.line, self.lexeme, self.message, @errorName(self.kind) },
            );
        } else {
            try output.print(
                "{s} [line {d}]: {s} ({s})\n",
                .{ self.stage.label(), self.line, self.message, @errorName(self.kind) },
            );
        }
    }
};

pub const Reporter = struct {
    const Self = @This();

    last: ?Diagnostic = null,

    pub fn report(self: *Self, diagnostic: Diagnostic) void {
        self.last = diagnostic;
    }

    pub fn clear(self: *Self) void {
        self.last = null;
    }

    pub fn printLast(self: *const Self, output: *Writer) Writer.Error!bool {
        const diagnostic = self.last orelse return false;
        try diagnostic.print(output);
        return true;
    }
};
