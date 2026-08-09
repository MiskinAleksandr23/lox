const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Expr = @import("expr.zig").Expr;

pub const Parser = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    tokens: std.ArrayList(Token),
    current: usize = 0,

    pub fn init(tokens: std.ArrayList(Token), alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .tokens = tokens,
        };
    }

    fn expression(self: *Self) *Expr {
        return self.equality();
    }

    fn equality(self: *Self) *Expr {
        var expr = self.comparison();

        while (self.matchMultipleChoise(.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const operator: Token = self.previousUnchecked();
            const right = self.comparison();

            expr = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
        }

        return expr;
    }
    inline fn advanceUnckecked(self: *Self) void {
        self.current += 1;
    }

    inline fn peekUnchecked(self: *Self) Token {
        self.tokens[self.current];
    }

    inline fn isAtEnd(self: *Self) bool {
        return self.current >= self.tokens.items.len;
    }

    fn check(self: *Self, tokenType: TokenType) bool {
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return false;
        }
        return self.peekUnchecked().tokenType == tokenType;
    }

    fn peek(self: *Self) Token {
        std.debug.assert(!self.isAtEnd());
        return self.peekUnchecked();
    }

    fn previousUnchecked(self: *Self) Token {
        std.debug.assert(self.current != 0);
        self.tokens[self.current - 1];
    }

    fn matchMultipleChoise(self: *Self, tokenTypes: []const TokenType) bool {
        for (tokenTypes) |tokenType| {
            if (self.check(tokenType)) {
                self.advanceUnckecked();
                return true;
            }
        }
        return false;
    }
    fn match(self: *Self, tokenType: TokenType) bool {
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return false;
        }

        return self.peekUnchecked().tokenType == tokenType;
    }

    fn comparison(self: *Self) *Expr {
        var expr = self.term();

        while (self.matchMultipleChoise(.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
            const operator = self.previousUnchecked();
            const right = self.term();

            expr = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
        }

        return expr;
    }

    fn term(self: *Self) *Expr {
        _ = self;
    }

    fn factor(self: *Self) *Expr {
        _ = self;
    }

    fn unary(self: *Self) *Expr {
        if (self.matchMultipleChoise(.{ .BANG, .MINUS })) {
            const operator = self.previousUnchecked();
            const right = self.unary();

            return .{ .unary = .{
                .operator = operator,
                .right = right,
            } };
        }

        return self.primary();
    }

    fn primary(self: *Self) *Expr {
        if (self.match(.FALSE)) {
            return null;
        } else if (self.match(.TRUE)) {
            return null;
        } else if (self.match(.NIL)) {
            return null;
        } else {
            return null;
        }
    }
};
