const std = @import("std");
const Io = std.Io;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Scanner = struct {
    const Self = @This();

    source: []const u8,
    tokens: std.ArrayList(Token),

    allocator: std.mem.Allocator,

    start: usize = 0,
    current: usize = 0,
    line: usize = 1,

    ident_map: std.StaticStringMap(TokenType),

    pub fn init(alloc: std.mem.Allocator, source: []const u8) !Self {
        return Self{ .source = source, .tokens = try .initCapacity(alloc, 42), .allocator = alloc, .ident_map = .initComptime(
            .{ .{ "and", .AND }, .{ "class", .CLASS }, .{ "else", .ELSE }, .{ "false", .FALSE }, .{ "fun", .FUN }, .{ "for", .FOR }, .{ "if", .IF }, .{ "nil", .NIL }, .{ "or", .OR }, .{ "print", .PRINT }, .{ "return", .RETURN }, .{ "super", .SUPER }, .{ "this", .THIS }, .{ "true", .TRUE }, .{ "var", .VAR }, .{ "while", .WHILE } },
        ) };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
    }

    pub fn scanTokens(self: *Self) !void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }
        // TODO: do we need .EOF?
        // try self.addToken(.EOF);
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.source.len;
    }

    // TODO: support comments
    fn scanToken(self: *Self) !void {
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

            '\"' => {
                try self.scanStringLiteral();
            },

            else => {
                if (isDigit(c)) {
                    try self.scanNumber();
                } else if (isAlpha(c)) {
                    try self.scanIdentifierOrKeyWord();
                } else {
                    const error_pos = std.mem.indexOfScalar(u8, self.source[self.start..], '\n');
                    const line: []const u8 = if (error_pos) |p| self.source[self.start .. self.start + p] else "Can't show error"[0..]; // TODO: better comment
                    std.debug.print("Error in line: {s}\n", .{line});
                    return error.UnexpectedCharacter;
                }
            },
        }
    }

    fn advance(self: *Self) u8 {
        std.debug.assert(!self.isAtEnd()); // TODO: better error

        const symbol = self.source[self.current];
        self.current += 1;
        return symbol;
    }
    fn addToken(self: *Self, token: TokenType) !void {
        try self.tokens.append(self.allocator, Token.init(token, self.source[self.start..self.current], self.line));
    }

    fn peek(self: *Self) u8 {
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return 0;
        }
        return self.source[self.current];
    }

    fn scanStringLiteral(self: *Self) !void {
        while (self.peek() != '\"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
            }
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return error.UnterminatedString;
        }

        // Closing double quote
        _ = self.advance();

        try self.addToken(.STRING);
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c == '_');
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    // TODO: currently supporting only unsigned integers
    fn scanNumber(self: *Self) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }
        try self.addToken(.NUMBER);
    }

    fn scanIdentifierOrKeyWord(self: *Self) !void {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        const ident = self.source[self.start..self.current];
        if (self.ident_map.get(ident)) |token_type| {
            // KeyWord
            try self.addToken(token_type);
        } else {
            // Identifier
            try self.addToken(.IDENTIFIER);
        }
    }

    /// If the current byte matches `expected`, consumes it and returns true.
    /// Otherwise, leaves the input unchanged and returns false.
    fn matchAdvance(self: *Self, expected: u8) bool {
        std.debug.assert(self.current <= self.source.len);
        if (self.peek() == expected) {
            self.current += 1;
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
