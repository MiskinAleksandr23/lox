const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ScannerError = @import("errors.zig").ScannerError;

pub const Scanner = struct {
    const Self = @This();

    source: []const u8,
    tokens: std.ArrayList(Token),

    allocator: std.mem.Allocator,

    start: usize = 0,
    current: usize = 0,
    line: usize = 1,

    identMap: std.StaticStringMap(TokenType),

    pub fn init(alloc: std.mem.Allocator, source: []const u8) !Self {
        return Self{
            .source = source,
            .tokens = try .initCapacity(alloc, 42),
            .allocator = alloc,
            .identMap = .initComptime(
                .{
                    .{ "and", .AND },
                    .{ "class", .CLASS },
                    .{ "else", .ELSE },
                    .{ "false", .FALSE },
                    .{ "fun", .FUN },
                    .{ "for", .FOR },
                    .{ "if", .IF },
                    .{ "nil", .NIL },
                    .{ "or", .OR },
                    .{ "print", .PRINT },
                    .{ "return", .RETURN },
                    .{ "super", .SUPER },
                    .{ "this", .THIS },
                    .{ "true", .TRUE },
                    .{ "var", .VAR },
                    .{ "while", .WHILE },
                },
            ),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
    }

    pub fn scanTokens(self: *Self) ScannerError!void {
        while (!self.isAtEnd()) {
            try self.scanToken();
            self.start = self.current;
        }
        std.debug.assert(self.current == self.source.len);
        try self.addToken(.EOF);
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.source.len;
    }

    fn scanToken(self: *Self) ScannerError!void {
        const c = self.advance();
        switch (c) {
            '(' => {
                try self.addToken(.LEFT_PAREN);
            },
            ')' => {
                try self.addToken(.RIGHT_PAREN);
            },
            '{' => {
                try self.addToken(.LEFT_BRACE);
            },
            '}' => {
                try self.addToken(.RIGHT_BRACE);
            },
            ',' => {
                try self.addToken(.COMMA);
            },
            '.' => {
                try self.addToken(.DOT);
            },
            '-' => {
                try self.addToken(.MINUS);
            },
            '+' => {
                try self.addToken(.PLUS);
            },
            ';' => {
                try self.addToken(.SEMICOLON);
            },
            '*' => {
                try self.addToken(.STAR);
            },
            '=' => {
                if (self.matchAdvance('=')) {
                    try self.addToken(.EQUAL_EQUAL);
                } else {
                    try self.addToken(.EQUAL);
                }
            },
            '>' => {
                if (self.matchAdvance('=')) {
                    try self.addToken(.GREATER_EQUAL);
                } else {
                    try self.addToken(.GREATER);
                }
            },
            '<' => {
                if (self.matchAdvance('=')) {
                    try self.addToken(.LESS_EQUAL);
                } else {
                    try self.addToken(.LESS);
                }
            },
            '!' => {
                if (self.matchAdvance('=')) {
                    try self.addToken(.BANG_EQUAL);
                } else {
                    try self.addToken(.BANG);
                }
            },

            ' ' => {},
            '\r' => {},
            '\t' => {},
            '\n' => {
                self.line += 1;
            },
            '/' => {
                if (self.matchAdvance('/')) {
                    while (!self.isAtEnd() and self.peekUnchecked() != '\n') {
                        self.advanceUnchecked();
                    }
                } else {
                    try self.addToken(.SLASH);
                }
            },

            '\"' => {
                try self.scanStringLiteral();
            },

            else => {
                if (isDigit(c)) {
                    try self.scanNumber();
                } else if (isAlpha(c)) {
                    try self.scanIdentifierOrKeyword();
                } else {
                    const error_pos = std.mem.indexOfScalar(u8, self.source[self.start..], '\n');
                    const error_line: []const u8 = if (error_pos) |pos| self.source[self.start .. self.start + pos] else "Can't show error source";
                    reportError(self.line, error_line, "Unexpected token");
                    return error.InvalidCharacter;
                }
            },
        }
    }

    fn advance(self: *Self) u8 {
        std.debug.assert(!self.isAtEnd());
        const symbol = self.peekUnchecked();
        self.advanceUnchecked();
        return symbol;
    }
    inline fn addToken(self: *Self, token: TokenType) ScannerError!void {
        try self.tokens.append(self.allocator, Token.init(token, self.source[self.start..self.current], self.line));
    }

    fn peek(self: *Self) u8 {
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return 0;
        }
        return self.source[self.current];
    }

    inline fn peekUnchecked(self: *Self) u8 {
        return self.source[self.current];
    }

    inline fn advanceUnchecked(self: *Self) void {
        self.current += 1;
    }

    fn scanStringLiteral(self: *Self) ScannerError!void {
        while (!self.isAtEnd() and self.peekUnchecked() != '\"') {
            if (self.peekUnchecked() == '\n') {
                self.line += 1;
            }
            self.advanceUnchecked();
        }
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return error.UnterminatedString;
        }
        self.advanceUnchecked();
        try self.addToken(.STRING);
    }

    inline fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c == '_');
    }

    inline fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    inline fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    fn scanNumber(self: *Self) ScannerError!void {
        while (!self.isAtEnd() and isDigit(self.peekUnchecked())) {
            self.advanceUnchecked();
        }
        try self.addToken(.NUMBER);
    }

    fn scanIdentifierOrKeyword(self: *Self) ScannerError!void {
        while (!self.isAtEnd() and isAlphaNumeric(self.peekUnchecked())) {
            self.advanceUnchecked();
        }
        const ident = self.source[self.start..self.current];
        if (self.identMap.get(ident)) |token_type| {
            try self.addToken(token_type);
        } else {
            try self.addToken(.IDENTIFIER);
        }
    }

    /// If the current byte matches `expected`, consumes it and returns true.
    /// Otherwise, leaves the input unchanged and returns false.
    fn matchAdvance(self: *Self, expected: u8) bool {
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return false;
        }
        if (self.peekUnchecked() == expected) {
            self.advanceUnchecked();
            return true;
        }
        return false;
    }

    /// If the upcoming input matches `pattern`, consumes it and returns true.
    /// Otherwise, leaves the input unchanged and returns false.
    fn matchAdvancePattern(self: *Self, pattern: []const u8) bool {
        const remaining = self.source[self.current..];
        if (std.mem.startsWith(u8, remaining, pattern)) {
            self.current += pattern.len;
            return true;
        }
        return false;
    }

    fn reportError(line: usize, where: []const u8, message: []const u8) void {
        std.debug.print("Error: {s}\n{d} | {s}\n", .{ message, line, where });
    }
};

test "Hello world!" {
    const allocator = std.testing.allocator;
    const program: []const u8 = "print \"Hello World!\";";

    var scanner = try Scanner.init(allocator, program);
    defer scanner.deinit();

    try scanner.scanTokens();
    const tokens: []const Token = scanner.tokens.items;

    try std.testing.expect(Token.eql(tokens[0], Token.init(.PRINT, "print", 1)));
    try std.testing.expect(Token.eql(tokens[1], Token.init(.STRING, "\"Hello World!\"", 1)));
    try std.testing.expect(Token.eql(tokens[2], Token.init(.SEMICOLON, ";", 1)));
}

test "Unterminated String Error" {
    const allocator = std.testing.allocator;
    const program: []const u8 =
        "print \"Hello World!;";

    var scanner = try Scanner.init(allocator, program);
    defer scanner.deinit();

    try std.testing.expectError(error.UnterminatedString, scanner.scanTokens());
}

test "Comments" {
    const allocator = std.testing.allocator;
    const program: []const u8 = "// comment here <_> 42 67 69";

    var scanner = try Scanner.init(allocator, program);
    defer scanner.deinit();

    try scanner.scanTokens();

    try std.testing.expect(scanner.tokens.items.len == 1);
    try std.testing.expect(Token.eql(scanner.tokens.items[0], Token.init(.EOF, "", 1)));
}
