const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Expr = @import("expr.zig").Expr;

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

    pub fn expression(self: *Self) *Expr {
        return self.equality();
    }

    fn equality(self: *Self) *Expr {
        var expr = self.comparison();

        while (self.matchMultipleChoise(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            // safety: we already matched -> current > 0
            const operator = self.previousUnchecked();
            const right = self.comparison();

            expr = self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }

        return expr;
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
        if (self.isAtEnd()) {
            @branchHint(.unlikely);
            return false;
        }
        if (self.peekUnchecked().tokenType == tokenType) {
            self.advanceUnckecked();
            return true;
        }
        return false;
    }

    fn peek(self: *Self) Token {
        std.debug.assert(!self.isAtEnd());
        return self.peekUnchecked();
    }

    fn previousUnchecked(self: *Self) Token {
        return self.tokens[self.current - 1];
    }

    // Todo: write about advance
    fn matchMultipleChoise(self: *Self, tokenTypes: []const TokenType) bool {
        for (tokenTypes) |tokenType| {
            if (self.match(tokenType)) {
                return true;
            }
        }
        return false;
    }

    fn comparison(self: *Self) *Expr {
        var expr = self.term();

        while (self.matchMultipleChoise(&.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
            // safety: we already matched -> current > 0
            const operator = self.previousUnchecked();
            const right = self.term();

            expr = self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }

        return expr;
    }

    fn term(self: *Self) *Expr {
        var expr = self.factor();

        while (self.matchMultipleChoise(&.{ .MINUS, .PLUS })) {
            // safety: we already matched -> current > 0
            const operator = self.previousUnchecked();
            const right = self.factor();

            expr = self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }
        return expr;
    }

    fn factor(self: *Self) *Expr {
        var expr = self.unary();

        while (self.matchMultipleChoise(&.{ .MINUS, .PLUS })) {
            // safety: we already matched -> current > 0
            const operator = self.previousUnchecked();
            const right = self.unary();

            expr = self.allocExpr(.{
                .binary = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            });
        }
        return expr;
    }

    fn unary(self: *Self) *Expr {
        if (self.matchMultipleChoise(&.{ .BANG, .MINUS })) {
            // safety: we already matched -> current > 0
            const operator = self.previousUnchecked();
            const right = self.unary();

            return self.allocExpr(.{
                .unary = .{
                    .operator = operator,
                    .right = right,
                },
            });
        }

        return self.primary();
    }

    fn primary(self: *Self) *Expr {
        if (self.match(.FALSE)) { // TODO: fix
            return self.allocExpr(.{
                .literal = .{
                    // safety: already matched -> current > 0
                    .value = .{
                        .boolean = false,
                    },
                },
            });
        } else if (self.match(.TRUE)) { // TODO: fix
            return self.allocExpr(.{
                .literal = .{
                    // safety: already matched -> current > 0
                    .value = .{
                        .boolean = true,
                    },
                },
            });
            // TODO: suppport nil
            // } else if (self.match(.NIL)) {
            //     return self.allocExpr(.{
            //         .literal = .{
            //             // safety: already matched -> current > 0
            //             .value = self.peekUnchecked().lexeme,
            //         },
            //     });
        } else if (self.match(.NUMBER)) {
            return self.allocExpr(.{
                .literal = .{
                    // safety: already matched -> current > 0
                    .value = .{
                        .integer = std.fmt.parseInt(i64, self.previousUnchecked().lexeme, 10) catch {
                            // TODO: can't parse
                            self.reportError();
                            unreachable;
                        },
                    },
                },
            });
        } else if (self.match(.STRING)) {
            return self.allocExpr(.{
                .literal = .{
                    // safety: already matched -> current > 0
                    .value = .{
                        .string = self.previousUnchecked().lexeme,
                    },
                },
            });
        } else if (self.match(.LEFT_PAREN)) {
            const expr = self.expression();
            self.consume(.RIGHT_PAREN, "Expect ')' after expression."); // TODO

            return self.allocExpr(.{
                .grouping = .{
                    .expr = expr,
                },
            });
        } else {
            unreachable;
        }
    }
    fn consume(self: *Self, tokenType: TokenType, errorMessage: []const u8) void {
        if (self.match(tokenType)) {
            return;
        }
        std.debug.panic("Error: {s}", .{errorMessage});
    }

    fn allocExpr(self: *Self, expr: Expr) *Expr {
        const element = self.alloc.create(Expr) catch {
            self.reportError();
            unreachable; // TODO
        };
        element.* = expr;
        return element;
    }
    fn reportError(self: *Self) void {
        _ = self;
    }
};
