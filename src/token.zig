const std = @import("std");

// https://craftinginterpreters.com/scanning.html
pub const TokenType = enum {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    IDENTIFIER,
    STRING,
    NUMBER,

    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    EOF,
};

pub const Token = struct {
    const Self = @This();

    tokenType: TokenType,
    lexeme: []const u8,
    line: usize,

    pub fn init(tokenType: TokenType, lexeme: []const u8, line: usize) Self {
        return Self{
            .tokenType = tokenType,
            .lexeme = lexeme,
            .line = line,
        };
    }

    pub fn eql(lhs: Token, rhs: Token) bool {
        return lhs.line == rhs.line and
            lhs.tokenType == rhs.tokenType and
            std.mem.eql(u8, lhs.lexeme, rhs.lexeme);
    }
};
