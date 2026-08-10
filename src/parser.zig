const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Expr = @import("expr.zig").Expr;
const ParseError = @import("errors.zig").ParseError;

pub const Parser = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    tokens: []const Token,
    current: usize = 0,

    pub fn init(tokens: []const Token, alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .tokens = tokens,
        };
    }

    inline fn advanceUnckecked(self: *Self) void {
        self.current += 1;
    }

    inline fn peekUnchecked(self: *Self) Token {
        return self.tokens[self.current];
    }

    inline fn isAtEnd(self: *Self) bool {
        return self.current >= self.tokens.len;
    }

    fn check(self: *Self, tokenType: TokenType) bool {
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return false;
        }
        return self.peekUnchecked().tokenType == tokenType;
    }

    fn match(self: *Self, tokenType: TokenType) bool {
        if (self.check(tokenType)) {
            self.advanceUnckecked();
            return true;
        }
        return false;
    }

    fn previousUnchecked(self: *Self) Token {
        return self.tokens[self.current - 1];
    }

    fn matchAny(self: *Self, tokenTypes: []const TokenType) bool {
        for (tokenTypes) |tokenType| {
            if (self.match(tokenType)) {
                return true;
            }
        }
        return false;
    }

    // expression     → equality ;
    // equality       → comparison ( ( "!=" | "==" ) comparison )* ;
    // comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
    // term           → factor ( ( "-" | "+" ) factor )* ;
    // factor         → unary ( ( "/" | "*" ) unary )* ;
    // unary          → ( "!" | "-" ) unary
    //             | primary ;
    // primary        → NUMBER | STRING | "true" | "false" | "nil"
    //             | "(" expression ")" ;

    pub fn expression(self: *Self) ParseError!*const Expr {
        return self.equality();
    }

    fn equality(self: *Self) ParseError!*const Expr {
        var expr = try self.comparison();

        while (self.matchAny(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const operator = self.previousUnchecked();
            const right = try self.comparison();

            expr = try self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }

        return expr;
    }

    fn comparison(self: *Self) ParseError!*const Expr {
        var expr = try self.term();

        while (self.matchAny(&.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
            const operator = self.previousUnchecked();
            const right = try self.term();

            expr = try self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }

        return expr;
    }

    fn term(self: *Self) ParseError!*const Expr {
        var expr = try self.factor();

        while (self.matchAny(&.{ .MINUS, .PLUS })) {
            const operator = self.previousUnchecked();
            const right = try self.factor();

            expr = try self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }
        return expr;
    }

    fn factor(self: *Self) ParseError!*const Expr {
        var expr = try self.unary();

        while (self.matchAny(&.{ .SLASH, .STAR })) {
            const operator = self.previousUnchecked();
            const right = try self.unary();

            expr = try self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }
        return expr;
    }

    fn unary(self: *Self) ParseError!*const Expr {
        if (self.matchAny(&.{ .BANG, .MINUS })) {
            const operator = self.previousUnchecked();
            const right = try self.unary();

            return try self.allocExpr(.{
                .unary = .{
                    .operator = operator,
                    .right = right,
                },
            });
        }

        return try self.primary();
    }

    fn primary(self: *Self) ParseError!*const Expr {
        if (self.match(.FALSE)) {
            return try self.allocExpr(.{
                .literal = .{
                    .value = .{
                        .boolean = false,
                    },
                },
            });
        } else if (self.match(.TRUE)) {
            return try self.allocExpr(.{
                .literal = .{
                    .value = .{
                        .boolean = true,
                    },
                },
            });
        } else if (self.match(.NUMBER)) {
            return try self.allocExpr(.{
                .literal = .{
                    .value = .{
                        .number = try std.fmt.parseInt(i64, self.previousUnchecked().lexeme, 10),
                    },
                },
            });
        } else if (self.match(.STRING)) {
            return try self.allocExpr(.{
                .literal = .{
                    .value = .{
                        .string = self.previousUnchecked().lexeme,
                    },
                },
            });
        } else if (self.match(.LEFT_PAREN)) {
            const expr = try self.expression();
            self.consume(.RIGHT_PAREN, "Expect ')' after expression.");

            return try self.allocExpr(.{
                .grouping = .{
                    .expr = expr,
                },
            });
        } else {
            return error.InvalidSyntax;
        }
    }
    fn consume(self: *Self, tokenType: TokenType, errorMessage: []const u8) void {
        if (self.match(tokenType)) {
            return;
        }
        self.reportError(errorMessage);
    }

    fn allocExpr(self: *Self, expr: Expr) ParseError!*Expr {
        const element = try self.alloc.create(Expr);
        element.* = expr;
        return element;
    }

    fn reportError(self: *Self, errorMessage: []const u8) void {
        _ = self;
        std.debug.panic("Error: {s}", .{errorMessage});
    }
};
