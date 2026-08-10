const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Expr = @import("expr.zig").Expr;
const Value = @import("expr.zig").Value;
const Literal = @import("expr.zig").Literal;
const Unary = @import("expr.zig").Unary;
const Binary = @import("expr.zig").Binary;
const Grouping = @import("expr.zig").Grouping;
const InterpreterFailure = @import("errors.zig").InterpreterFailure;

pub const Interpreter = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
        };
    }

    pub fn evaluate(self: *Self, expr: *const Expr) InterpreterFailure!Value {
        return switch (expr.*) {
            .literal => |literal| self.evaluateLiteral(literal),
            .unary => |unary| try self.evaluateUnary(unary),
            .binary => |binary| try self.evaluateBinary(binary),
            .grouping => |grouping| try self.evaluateGrouping(grouping),
            else => return InterpreterFailure.Unimplemented,
        };
    }

    fn evaluateLiteral(_: *Self, literal: Literal) Value {
        return literal.value;
    }

    fn evaluateUnary(self: *Self, unary: Unary) InterpreterFailure!Value {
        const value = try self.evaluate(unary.right);

        return switch (unary.operator.tokenType) {
            .MINUS => switch (value) {
                .number => |number| .{ .number = -number },
                else => self.failRuntime(unary.operator, InterpreterFailure.InvalidOperand, "Operand must be a number"),
            },
            .BANG => switch (value) {
                .number => .{ .boolean = false },
                .nil => .{ .boolean = true },
                .boolean => |boolean| .{ .boolean = !boolean },
                .string => .{ .boolean = false },
            },
            else => unreachable,
        };
    }

    fn evaluateGrouping(self: *Self, grouping: Grouping) InterpreterFailure!Value {
        return try self.evaluate(grouping.expr);
    }

    fn evaluateBinary(self: *Self, binary: Binary) InterpreterFailure!Value {
        const left = try self.evaluate(binary.left);
        const right = try self.evaluate(binary.right);

        return switch (binary.operator.tokenType) {
            .PLUS => try self.evaluatePlus(binary.operator, left, right),
            .MINUS, .STAR, .SLASH, .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL => try self.evaluateNumericBinary(binary.operator, left, right),
            .EQUAL_EQUAL => .{ .boolean = self.equalValues(left, right) },
            .BANG_EQUAL => .{ .boolean = !self.equalValues(left, right) },
            else => InterpreterFailure.Unimplemented,
        };
    }

    fn evaluatePlus(self: *Self, operator: Token, left: Value, right: Value) InterpreterFailure!Value {
        return switch (left) {
            .number => |lhs| .{
                .number = lhs + try self.requireNumber(operator, left),
            },
            .string => |lhs| .{
                .string = try std.mem.concat(self.alloc, u8, &.{
                    lhs,
                    try self.requireString(operator, right),
                }),
            },
            else => self.failRuntime(operator, InterpreterFailure.InvalidOperand, "Operands must be two numbers or two strings"),
        };
    }

    fn evaluateNumericBinary(self: *Self, operator: Token, left: Value, right: Value) InterpreterFailure!Value {
        const lhs = try self.requireNumber(operator, left);
        const rhs = try self.requireNumber(operator, right);

        return switch (operator.tokenType) {
            .PLUS => .{
                .number = lhs + rhs,
            },
            .MINUS => .{
                .number = lhs - rhs,
            },
            .STAR => .{
                .number = lhs * rhs,
            },
            .SLASH => division: {
                if (rhs == 0) {
                    return self.failRuntime(operator, InterpreterFailure.DivisionByZero, "Division by zero");
                }
                break :division .{
                    .number = @divTrunc(lhs, rhs),
                };
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
            else => InterpreterFailure.Unimplemented,
        };
    }

    fn equalValues(self: *Self, left: Value, right: Value) bool {
        _ = self;
        switch (left) {
            .number => |lhs| {
                switch (right) {
                    .number => |rhs| {
                        return lhs == rhs;
                    },
                    else => return false,
                }
            },
            .nil => {
                switch (right) {
                    .nil => return true,
                    else => return false,
                }
            },
            .string => |lhs| {
                switch (right) {
                    .string => |rhs| return std.mem.eql(u8, lhs, rhs),
                    else => return false,
                }
            },
            .boolean => |lhs| {
                switch (right) {
                    .boolean => |rhs| return lhs == rhs,
                    else => return false,
                }
            },
        }
    }

    fn failRuntime(self: *Self, token: Token, err: InterpreterFailure, errMessage: []const u8) InterpreterFailure {
        _ = token;
        _ = self;
        _ = errMessage;
        return err;
    }

    fn requireNumber(self: *Self, operator: Token, value: Value) InterpreterFailure!i64 {
        return switch (value) {
            .number => |number| number,
            else => self.failRuntime(operator, InterpreterFailure.InvalidOperand, "Operand must be a number"),
        };
    }

    fn requireString(self: *Self, operator: Token, value: Value) InterpreterFailure![]const u8 {
        return switch (value) {
            .string => |string| string,
            else => self.failRuntime(operator, InterpreterFailure.InvalidOperand, "Operand must be a string"),
        };
    }
};
