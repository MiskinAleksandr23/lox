const std = @import("std");
const Expr = @import("expr.zig").Expr;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Value = @import("expr.zig").Value;
const RuntimeError = @import("errors.zig").RuntimeError;
const Literal = @import("expr.zig").Literal;
const Unary = @import("expr.zig").Unary;
const Binary = @import("expr.zig").Binary;
const Grouping = @import("expr.zig").Grouping;

pub const Interpreter = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
        };
    }

    pub fn evaluate(self: *Self, expr: *const Expr) RuntimeError!Value {
        return switch (expr.*) {
            .literal => |literal| try self.evaluateLiteralExpr(literal),
            .unary => |unary| try self.evaluateUnaryExpression(unary),
            .binary => |binary| try self.evaluateBinaryExpression(binary),
            .grouping => |grouping| try self.evaluateGroupingExpr(grouping),
            else => RuntimeError.InvalidOperand,
        };
    }

    fn evaluateLiteralExpr(self: *Self, literal: Literal) RuntimeError!Value {
        _ = self;
        return literal.value;
    }

    fn evaluateUnaryExpression(self: *Self, unary: Unary) RuntimeError!Value {
        const internal = try self.evaluate(unary.right);

        if (unary.operator.tokenType == .MINUS) {
            return switch (internal) {
                .number => |number| .{ .number = -number },
                else => RuntimeError.InvalidOperand,
            };
        } else if (unary.operator.tokenType == .BANG) {
            return switch (internal) {
                .boolean => |boolean| .{ .boolean = !boolean },
                else => RuntimeError.InvalidOperand,
            };
        }
        return RuntimeError.InvalidOperand;
    }

    fn evaluateBinaryExpression(self: *Self, binary: Binary) RuntimeError!Value {
        const left = try self.evaluate(binary.left);
        const right = try self.evaluate(binary.right);

        switch (binary.operator.tokenType) {
            .PLUS => return try self.addValues(left, right),
            .MINUS, .STAR, .SLASH, .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL => return try self.handleNumbers(binary.operator.tokenType, left, right),
            else => {},
        }
        return error.InvalidOperand;
    }
    fn evaluateGroupingExpr(self: *Self, grouping: Grouping) RuntimeError!Value {
        return try self.evaluate(grouping.expr);
    }

    fn addValues(self: *Self, left: Value, right: Value) RuntimeError!Value {
        return switch (left) {
            .number => |lhs| switch (right) {
                .number => |rhs| .{
                    .number = lhs + rhs,
                },
                else => self.failError(),
            },
            .string => |lhs| switch (right) {
                .string => |rhs| .{
                    .string = try std.mem.concat(self.alloc, u8, &.{ lhs, rhs }),
                },
                else => self.failError(),
            },
            else => self.failError(),
        };
    }

    fn handleNumbers(self: *Self, operator: TokenType, left: Value, right: Value) RuntimeError!Value {
        return switch (left) {
            .number => |lhs| switch (right) {
                .number => |rhs| switch (operator) {
                    .PLUS => .{
                        .number = lhs + rhs,
                    },
                    .MINUS => .{
                        .number = lhs - rhs,
                    },
                    .STAR => .{
                        .number = lhs * rhs,
                    },
                    .SLASH => .{
                        .number = @divExact(lhs, rhs),
                    },
                    .LESS => .{
                        .boolean = lhs < rhs,
                    },
                    .GREATER => .{
                        .boolean = lhs > rhs,
                    },
                    .LESS_EQUAL => .{
                        .boolean = lhs <= rhs,
                    },
                    .GREATER_EQUAL => .{
                        .boolean = lhs >= rhs,
                    },
                    else => self.failError(),
                },
                else => self.failError(),
            },
            else => self.failError(),
        };
    }
    fn failError(self: *Self) RuntimeError {
        _ = self;
        // TODO: fix
        return error.InvalidOperand;
    }
};
