const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Expr = @import("expr.zig").Expr;
const Value = @import("expr.zig").Value;
const Literal = @import("expr.zig").Literal;
const Unary = @import("expr.zig").Unary;
const Binary = @import("expr.zig").Binary;
const Assign = @import("expr.zig").Assign;
const Grouping = @import("expr.zig").Grouping;
const Variable = @import("expr.zig").Variable;
const VarStmt = @import("stmt.zig").VarStmt;
const Expression = @import("stmt.zig").Expression;
const InterpreterFailure = @import("errors.zig").InterpreterFailure;
const Stmt = @import("stmt.zig").Stmt;
const IfStmt = @import("stmt.zig").IfStmt;
const Block = @import("stmt.zig").Block;
const PrintStmt = @import("stmt.zig").PrintStmt;
const WhileStmt = @import("stmt.zig").WhileStmt;
const Environment = @import("environment.zig").Environment;

pub const Interpreter = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    environment: Environment,
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .environment = .init(alloc),
        };
    }

    pub fn interpret(self: *Self, stmts: []*const Stmt) InterpreterFailure!void {
        for (stmts) |stmt| {
            try self.execute(stmt);
        }
    }

    fn execute(self: *Self, stmt: *const Stmt) InterpreterFailure!void {
        switch (stmt.*) {
            .printStmt => |printStmt| {
                try self.executePrint(printStmt);
            },
            .varStmt => |varStmt| {
                try self.executeVarStmt(varStmt);
            },
            .expression => |expression| {
                try self.executeExpression(expression);
            },
            .block => |block| {
                const environment = try self.alloc.create(Environment); // TODO
                environment.* = .init(self.alloc);
                try self.executeBlock(
                    block,
                    environment,
                );
            },
            .ifStmt => |ifStmt| {
                try self.executeIfStmt(ifStmt);
            },
            .whileStmt => |whileStmt| {
                try self.executeWhileStmt(whileStmt);
            },
            else => return InterpreterFailure.Unimplemented,
        }
    }

    // environment
    fn executeWhileStmt(self: *Self, whileStmt: WhileStmt) InterpreterFailure!void {
        while (isTruthy(try self.evaluate(whileStmt.condition))) {
            try self.execute(whileStmt.body);
        }
    }

    inline fn isTruthy(value: Value) bool {
        return switch (value) {
            .boolean => |boolean| boolean,
            .nil => false,
            .number, .string => true,
        };
    }

    fn executeIfStmt(self: *Self, ifStmt: IfStmt) InterpreterFailure!void {
        const value = try self.evaluate(ifStmt.condition);
        if (isTruthy(value)) {
            try self.execute(ifStmt.thenBranch);
        } else {
            try self.execute(ifStmt.elseBranch);
        }
    }

    fn executeBlock(self: *Self, block: Block, environment: *Environment) InterpreterFailure!void {
        var previous = self.environment;
        self.environment = environment.*;
        self.environment.enclosing = &previous;
        for (block.statements) |stmt| {
            try self.execute(stmt);
        }

        self.environment = previous;
    }

    fn executeExpression(self: *Self, expression: Expression) InterpreterFailure!void {
        _ = try self.evaluate(expression.expr);
    }

    fn executePrint(self: *Self, printStmt: PrintStmt) InterpreterFailure!void {
        const value = try self.evaluate(printStmt.expr);

        switch (value) {
            .number => |number| std.debug.print("{d}\n", .{number}),
            .string => |string| std.debug.print("{s}\n", .{string}),
            .boolean => |boolean| std.debug.print("{}\n", .{boolean}),
            .nil => std.debug.print("nil\n", .{}),
        }
    }
    fn executeVarStmt(self: *Self, varStmt: VarStmt) InterpreterFailure!void {
        const value = try self.evaluate(varStmt.initializer);
        try self.environment.define(varStmt.name.lexeme, value);
    }

    pub fn evaluate(self: *Self, expr: *const Expr) InterpreterFailure!Value {
        return switch (expr.*) {
            .binary => |binary| try self.evaluateBinary(binary),
            .literal => |literal| self.evaluateLiteral(literal),
            .unary => |unary| try self.evaluateUnary(unary),
            .grouping => |grouping| try self.evaluateGrouping(grouping),
            .variable => |variable| try self.evaluateVariable(variable),
            .assign => |assing| try self.evaluateAssing(assing),
            else => return InterpreterFailure.Unimplemented,
        };
    }

    fn evaluateAssing(self: *Self, assign: Assign) InterpreterFailure!Value {
        const evaluated = try self.evaluate(assign.value);
        try self.environment.assign(assign.token.lexeme, evaluated);
        return evaluated;
    }
    fn evaluateLiteral(_: *Self, literal: Literal) Value {
        return literal.value;
    }

    fn evaluateUnary(self: *Self, unary: Unary) InterpreterFailure!Value {
        const value = try self.evaluate(unary.right);

        return switch (unary.operator.tokenType) {
            .MINUS => switch (value) {
                .number => |number| .from(-number),
                else => self.failRuntime(unary.operator, InterpreterFailure.InvalidOperand, "Operand must be a number"),
            },
            .BANG => .from(!isTruthy(value)),
            else => unreachable,
        };
    }

    fn evaluateGrouping(self: *Self, grouping: Grouping) InterpreterFailure!Value {
        return try self.evaluate(grouping.expr);
    }

    fn evaluateVariable(self: *Self, variable: Variable) InterpreterFailure!Value {
        return try self.environment.get(variable.name.lexeme);
    }

    fn evaluateBinary(self: *Self, binary: Binary) InterpreterFailure!Value {
        const left = try self.evaluate(binary.left);
        const right = try self.evaluate(binary.right);

        return switch (binary.operator.tokenType) {
            .PLUS => try self.evaluatePlus(binary.operator, left, right),
            .MINUS, .STAR, .SLASH, .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL => try self.evaluateNumericBinary(binary.operator, left, right),
            .EQUAL_EQUAL => .from(self.equalValues(left, right)),
            .BANG_EQUAL => .from(!self.equalValues(left, right)),
            else => InterpreterFailure.Unimplemented,
        };
    }

    fn evaluatePlus(self: *Self, operator: Token, left: Value, right: Value) InterpreterFailure!Value {
        return switch (left) {
            .number => |lhs| switch (right) {
                .number => |rhs| .from(lhs + rhs),
                .string => |rhs| .from(try std.mem.concat(
                    self.alloc,
                    u8,
                    &.{ try self.stringify(left), rhs },
                )),
                else => self.failRuntime(operator, InterpreterFailure.InvalidOperand, "Operands must be numbers or strings"),
            },
            .string => |lhs| .from(try std.mem.concat(self.alloc, u8, &.{
                lhs,
                try self.stringify(right),
            })),
            else => self.failRuntime(operator, InterpreterFailure.InvalidOperand, "Operands must be numbers or strings"),
        };
    }

    fn stringify(self: *Self, value: Value) InterpreterFailure![]const u8 {
        return switch (value) {
            .number => |number| try std.fmt.allocPrint(
                self.alloc,
                "{d}",
                .{number},
            ),
            .string => |string| string,
            else => InterpreterFailure.InvalidOperand,
        };
    }

    fn evaluateNumericBinary(self: *Self, operator: Token, left: Value, right: Value) InterpreterFailure!Value {
        const lhs = try self.requireNumber(operator, left);
        const rhs = try self.requireNumber(operator, right);

        return switch (operator.tokenType) {
            .PLUS => .from(lhs + rhs),
            .MINUS => .from(lhs - rhs),
            .STAR => .from(lhs * rhs),,
            .SLASH => division: {
                if (rhs == 0) {
                    return self.failRuntime(operator, InterpreterFailure.DivisionByZero, "Division by zero");
                }
                break :division .from(@divTrunc(lhs, rhs));
            },
            .LESS => .from(lhs < rhs),
            .GREATER => .from(lhs > rhs),
            .LESS_EQUAL => .from(lhs <= rhs),
            .GREATER_EQUAL => .from(lhs >= rhs),
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
