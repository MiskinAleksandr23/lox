const std = @import("std");
const math = std.math;
const Writer = std.Io.Writer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Reporter = @import("diagnostic.zig").Reporter;
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
const RuntimeError = @import("errors.zig").RuntimeError;

pub const Interpreter = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    environment: *Environment,
    reporter: *Reporter,
    output: *Writer,
    diagnostics: *Writer,
    execution_depth: usize = 0,
    evaluation_depth: usize = 0,

    const max_recursion_depth = 512;

    pub fn init(alloc: std.mem.Allocator, environment: *Environment, reporter: *Reporter, output: *Writer, diagnostics: *Writer) Self {
        return Self{
            .alloc = alloc,
            .environment = environment,
            .reporter = reporter,
            .output = output,
            .diagnostics = diagnostics,
        };
    }

    pub fn interpret(self: *Self, stmts: []const *const Stmt) InterpreterFailure!void {
        for (stmts) |stmt| {
            try self.execute(stmt);
        }
    }

    fn execute(self: *Self, stmt: *const Stmt) InterpreterFailure!void {
        if (self.execution_depth >= max_recursion_depth) {
            return error.ExecutionDepthExceeded;
        }
        self.execution_depth += 1;
        defer self.execution_depth -= 1;

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
                var environment: Environment = .init(self.environment.alloc);
                defer environment.deinit();
                environment.enclosing = self.environment;
                try self.executeBlock(
                    block,
                    &environment,
                );
            },
            .ifStmt => |ifStmt| {
                try self.executeIfStmt(ifStmt);
            },
            .whileStmt => |whileStmt| {
                try self.executeWhileStmt(whileStmt);
            },
            else => return error.FeatureNotImplemented,
        }
    }

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
        } else if (ifStmt.elseBranch) |else_branch| {
            try self.execute(else_branch);
        }
    }

    fn executeBlock(self: *Self, block: Block, environment: *Environment) InterpreterFailure!void {
        const previous = self.environment;
        self.environment = environment;
        defer self.environment = previous;

        for (block.statements) |stmt| {
            try self.execute(stmt);
        }
    }

    fn executeExpression(self: *Self, expression: Expression) InterpreterFailure!void {
        _ = try self.evaluate(expression.expr);
    }

    fn executePrint(self: *Self, printStmt: PrintStmt) InterpreterFailure!void {
        const value = try self.evaluate(printStmt.expr);

        switch (value) {
            .number => |number| try self.output.print("{d}\n", .{number}),
            .string => |string| try self.output.print("{s}\n", .{string}),
            .boolean => |boolean| try self.output.print("{}\n", .{boolean}),
            .nil => try self.output.writeAll("nil\n"),
        }
    }
    fn executeVarStmt(self: *Self, varStmt: VarStmt) InterpreterFailure!void {
        const value = try self.evaluate(varStmt.initializer);
        const already_defined = try self.environment.define(varStmt.name.lexeme, value);
        if (already_defined) {
            try self.output.flush();
            try self.diagnostics.print(
                "Warning [line {d}]: Variable '{s}' is already declared in this scope.\n",
                .{ varStmt.name.line, varStmt.name.lexeme },
            );
            try self.diagnostics.flush();
        }
    }

    pub fn evaluate(self: *Self, expr: *const Expr) InterpreterFailure!Value {
        if (self.evaluation_depth >= max_recursion_depth) {
            return error.ExecutionDepthExceeded;
        }
        self.evaluation_depth += 1;
        defer self.evaluation_depth -= 1;

        return switch (expr.*) {
            .binary => |binary| try self.evaluateBinary(binary),
            .literal => |literal| self.evaluateLiteral(literal),
            .unary => |unary| try self.evaluateUnary(unary),
            .grouping => |grouping| try self.evaluateGrouping(grouping),
            .variable => |variable| try self.evaluateVariable(variable),
            .assign => |assing| try self.evaluateAssing(assing),
            else => return error.FeatureNotImplemented,
        };
    }

    fn evaluateAssing(self: *Self, assign: Assign) InterpreterFailure!Value {
        const evaluated = try self.evaluate(assign.value);
        self.environment.assign(assign.token.lexeme, evaluated) catch |err| {
            return self.failRuntime(
                assign.token,
                err,
                "Undefined variable.",
            );
        };
        return evaluated;
    }
    fn evaluateLiteral(_: *Self, literal: Literal) Value {
        return literal.value;
    }

    fn evaluateUnary(self: *Self, unary: Unary) InterpreterFailure!Value {
        const value = try self.evaluate(unary.right);

        return switch (unary.operator.tokenType) {
            .MINUS => switch (value) {
                .number => |number| .from(try self.negateInteger(unary.operator, number)),
                else => self.failRuntime(unary.operator, error.InvalidOperand, "Operand must be a number."),
            },
            .BANG => .from(!isTruthy(value)),
            else => unreachable,
        };
    }

    fn evaluateGrouping(self: *Self, grouping: Grouping) InterpreterFailure!Value {
        return try self.evaluate(grouping.expr);
    }

    fn evaluateVariable(self: *Self, variable: Variable) InterpreterFailure!Value {
        return self.environment.get(variable.name.lexeme) catch |err| {
            return self.failRuntime(
                variable.name,
                err,
                "Undefined variable.",
            );
        };
    }

    fn evaluateBinary(self: *Self, binary: Binary) InterpreterFailure!Value {
        const left = try self.evaluate(binary.left);
        const right = try self.evaluate(binary.right);

        return switch (binary.operator.tokenType) {
            .PLUS => try self.evaluatePlus(binary.operator, left, right),
            .MINUS, .STAR, .SLASH, .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL => try self.evaluateNumericBinary(binary.operator, left, right),
            .EQUAL_EQUAL => .from(self.equalValues(left, right)),
            .BANG_EQUAL => .from(!self.equalValues(left, right)),
            else => error.FeatureNotImplemented,
        };
    }

    fn evaluatePlus(self: *Self, operator: Token, left: Value, right: Value) InterpreterFailure!Value {
        return switch (left) {
            .number => |lhs| switch (right) {
                .number => |rhs| .from(try self.addIntegers(operator, lhs, rhs)),
                .string => |rhs| .from(try std.fmt.allocPrint(
                    self.alloc,
                    "{d}{s}",
                    .{ lhs, rhs },
                )),
                else => self.failRuntime(operator, error.InvalidOperand, "Operands must be numbers or strings."),
            },
            .string => |lhs| switch (right) {
                .number => |rhs| .from(try std.fmt.allocPrint(
                    self.alloc,
                    "{s}{d}",
                    .{ lhs, rhs },
                )),
                .string => |rhs| .from(try std.mem.concat(self.alloc, u8, &.{ lhs, rhs })),
                else => self.failRuntime(operator, error.InvalidOperand, "Operands must be numbers or strings."),
            },
            else => self.failRuntime(operator, error.InvalidOperand, "Operands must be numbers or strings."),
        };
    }

    fn evaluateNumericBinary(self: *Self, operator: Token, left: Value, right: Value) InterpreterFailure!Value {
        const lhs = try self.requireNumber(operator, left);
        const rhs = try self.requireNumber(operator, right);

        return switch (operator.tokenType) {
            .PLUS => .from(try self.addIntegers(operator, lhs, rhs)),
            .MINUS => .from(try self.subtractIntegers(operator, lhs, rhs)),
            .STAR => .from(try self.multiplyIntegers(operator, lhs, rhs)),
            .SLASH => .from(try self.divideIntegers(operator, lhs, rhs)),
            .LESS => .from(lhs < rhs),
            .GREATER => .from(lhs > rhs),
            .LESS_EQUAL => .from(lhs <= rhs),
            .GREATER_EQUAL => .from(lhs >= rhs),
            else => error.FeatureNotImplemented,
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

    fn failRuntime(self: *Self, token: Token, kind: RuntimeError, message: []const u8) RuntimeError {
        self.reporter.report(.{
            .stage = .runtime,
            .kind = kind,
            .line = token.line,
            .lexeme = token.lexeme,
            .message = message,
        });
        return kind;
    }

    fn negateInteger(self: *Self, operator: Token, value: i64) RuntimeError!i64 {
        return math.negate(value) catch {
            return self.failRuntime(operator, error.IntegerOverflow, "Integer overflow.");
        };
    }

    fn addIntegers(self: *Self, operator: Token, lhs: i64, rhs: i64) RuntimeError!i64 {
        return math.add(i64, lhs, rhs) catch {
            return self.failRuntime(operator, error.IntegerOverflow, "Integer overflow.");
        };
    }

    fn subtractIntegers(self: *Self, operator: Token, lhs: i64, rhs: i64) RuntimeError!i64 {
        return math.sub(i64, lhs, rhs) catch {
            return self.failRuntime(operator, error.IntegerOverflow, "Integer overflow.");
        };
    }

    fn multiplyIntegers(self: *Self, operator: Token, lhs: i64, rhs: i64) RuntimeError!i64 {
        return math.mul(i64, lhs, rhs) catch {
            return self.failRuntime(operator, error.IntegerOverflow, "Integer overflow.");
        };
    }

    fn divideIntegers(self: *Self, operator: Token, lhs: i64, rhs: i64) RuntimeError!i64 {
        return math.divTrunc(i64, lhs, rhs) catch |err| {
            return switch (err) {
                error.DivisionByZero => self.failRuntime(operator, error.DivisionByZero, "Division by zero."),
                error.Overflow => self.failRuntime(operator, error.IntegerOverflow, "Integer overflow."),
            };
        };
    }

    fn requireNumber(self: *Self, operator: Token, value: Value) RuntimeError!i64 {
        return switch (value) {
            .number => |number| number,
            else => self.failRuntime(operator, RuntimeError.InvalidOperand, "Operand must be a number."),
        };
    }
};
