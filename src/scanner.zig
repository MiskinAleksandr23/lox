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

    pub fn init(alloc: std.mem.Allocator, source: []const u8) !Self {
        return Self{
            .source = source,
            .tokens = try .initCapacity(alloc, 42),
            .allocator = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
    }

    pub fn scanTokens(self: *Self) !void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }
        try self.addToken(.EOF);
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.source.len;
    }

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
                if (self.peek() == '=') {
                    _ = self.advance();
                    try self.addToken(.EQUAL_EQUAL);
                } else {
                    try self.addToken(.EQUAL);
                }
            },
            '>' => {
                if (self.peek() == '=') {
                    _ = self.advance();
                    try self.addToken(.GREATER_EQUAL);
                } else {
                    try self.addToken(.GREATER);
                }
            },
            '<' => {
                if (self.peek() == '=') {
                    _ = self.advance();
                    try self.addToken(.LESS_EQUAL);
                } else {
                    try self.addToken(.LESS);
                }
            },
            '!' => {
                if (self.peek() == '=') {
                    _ = self.advance();
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
                    try self.scanIdentifier();
                } else {
                    std.debug.print("error in {s}\n: ", .{self.source[self.start .. self.start + 20]});
                    return error.UnexpectedCharacter;
                }
            },
        }
    }

    // Precondition: !self.isEnd()
    fn advance(self: *Self) u8 {
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
        const closed = self.advance(); // TODO: rename
        std.debug.assert(closed == '"'); // TODO: return error, not panic
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

    fn scanNumber(self: *Self) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }
        try self.addToken(.NUMBER);
    }

    fn scanIdentifier(self: *Self) !void {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        try self.addToken(.IDENTIFIER);
    }
};
