const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Reporter = @import("diagnostic.zig").Reporter;
const Expr = @import("expr.zig").Expr;
const ParserFailure = @import("errors.zig").ParserFailure;
const ParserError = @import("errors.zig").ParserError;
const Stmt = @import("stmt.zig").Stmt;
const Block = @import("stmt.zig").Block;
const IfStmt = @import("stmt.zig").IfStmt;
const WhileStmt = @import("stmt.zig").WhileStmt;

pub const Parser = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    tokens: []const Token,
    reporter: *Reporter,
    current: usize = 0,
    recursion_depth: usize = 0,

    const max_recursion_depth = 512;

    pub fn init(tokens: []const Token, alloc: std.mem.Allocator, reporter: *Reporter) Self {
        return Self{
            .alloc = alloc,
            .tokens = tokens,
            .reporter = reporter,
        };
    }

    inline fn advanceUnchecked(self: *Self) void {
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
            self.advanceUnchecked();
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

    fn matchAll(self: *Self, tokenTypes: []const TokenType) bool {
        for (tokenTypes, 0..) |tokenType, idx| {
            if (self.current + idx < self.tokens.len) {
                if (self.tokens[self.current + idx].tokenType != tokenType) {
                    return false;
                }
            } else {
                return false;
            }
        }
        self.current += tokenTypes.len;
        return true;
    }

    // program        → declaration*

    // declaration    → varDecl
    //                | statement

    // varDecl        → "var" IDENTIFIER ( "=" expression )? ";"

    // statement      → exprStmt
    //                | printStmt
    //                | blockStmt
    //                | ifStmt
    //                | whileStmt
    //                | forStmt

    // ifStmt         → "if" "(" expression ")" statement
    //                  ( "else" statement )?

    // whileStmt      → "while" "(" expression ")" statement

    // forStmt        → "for" "(" ( varDecl | exprStmt | ";" )
    //                  expression? ";" expression? ")" statement

    // exprStmt       → expression ";"
    // printStmt      → "print" expression ";"

    // blockStmt      → "{" declaration* "}"

    // expression     → assignment

    // assignment     → IDENTIFIER "=" assignment
    //                | equality

    // equality       → comparison ( ( "!=" | "==" ) comparison )*

    // comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )*

    // term           → factor ( ( "-" | "+" ) factor )*

    // factor         → unary ( ( "/" | "*" ) unary )*

    // unary          → ( "!" | "-" ) unary
    //                | primary

    // primary        → NUMBER | STRING | IDENTIFIER
    //                | "true" | "false" | "nil"
    //                | "(" expression ")"

    pub fn parse(self: *Self) ParserFailure![]const *const Stmt {
        var decls: std.ArrayList(*const Stmt) = .empty;
        while (!self.isAtEnd()) {
            try decls.append(self.alloc, try self.declaration());
        }
        return decls.items;
    }

    fn declaration(self: *Self) ParserFailure!*const Stmt {
        if (self.match(.VAR)) {
            return try self.varDeclaration();
        }
        return try self.statement();
    }

    fn varDeclaration(self: *Self) ParserFailure!*const Stmt {
        try self.consume(.IDENTIFIER, "Expect variable name.");
        const name = self.previousUnchecked();

        const initializer = if (self.match(.EQUAL))
            try self.expression()
        else
            try self.allocExpr(.{ .literal = .{ .value = .nil } });

        try self.consume(.SEMICOLON, "Expect ';' after variable declaration.");

        return self.allocStmt(.{
            .varStmt = .{
                .name = name,
                .initializer = initializer,
            },
        });
    }

    fn statement(self: *Self) ParserFailure!*const Stmt {
        try self.enterRecursiveRule();
        defer self.leaveRecursiveRule();

        if (self.match(.PRINT)) {
            return try self.printStatement();
        } else if (self.match(.LEFT_BRACE)) {
            return try self.blockStmt();
        } else if (self.match(.IF)) {
            return try self.ifStmt();
        } else if (self.match(.WHILE)) {
            return try self.whileStmt();
        } else if (self.match(.FOR)) {
            return try self.forStmt();
        }
        return try self.expressionStatement();
    }
    fn forStmt(self: *Self) ParserFailure!*const Stmt {
        try self.consume(.LEFT_PAREN, "Expect '(' after 'for'.");

        const initializer: ?*const Stmt = if (self.match(.SEMICOLON))
            null
        else if (self.match(.VAR))
            try self.varDeclaration()
        else
            try self.expressionStatement();

        const condition = if (!self.check(.SEMICOLON))
            try self.expression()
        else
            try self.allocExpr(.{ .literal = .{ .value = .{ .boolean = true } } });
        try self.consume(.SEMICOLON, "Expect ';' after loop condition.");

        const increment: ?*const Expr = if (!self.check(.RIGHT_PAREN))
            try self.expression()
        else
            null;
        try self.consume(.RIGHT_PAREN, "Expect ')' after for clauses.");

        var body = try self.statement();

        if (increment) |increment_expr| {
            const increment_stmt = try self.allocStmt(.{
                .expression = .{ .expr = increment_expr },
            });
            const statements = try self.alloc.dupe(
                *const Stmt,
                &.{ body, increment_stmt },
            );
            body = try self.allocStmt(.{
                .block = .{ .statements = statements },
            });
        }

        body = try self.allocStmt(.{
            .whileStmt = .{
                .condition = condition,
                .body = body,
            },
        });

        if (initializer) |initializer_stmt| {
            const statements = try self.alloc.dupe(
                *const Stmt,
                &.{ initializer_stmt, body },
            );
            body = try self.allocStmt(.{
                .block = .{ .statements = statements },
            });
        }

        return body;
    }

    fn blockStmt(self: *Self) ParserFailure!*const Stmt {
        var stmts: std.ArrayList(*const Stmt) = .empty;

        while (!self.check(.RIGHT_BRACE) and !self.isAtEnd()) {
            try stmts.append(self.alloc, try self.declaration());
        }
        try self.consume(.RIGHT_BRACE, "Expect '}' after block.");
        return try self.allocStmt(.{ .block = .{
            .statements = stmts.items,
        } });
    }

    fn whileStmt(self: *Self) ParserFailure!*const Stmt {
        try self.consume(.LEFT_PAREN, "Expect '(' after 'while'.");
        const condition = try self.expression();

        try self.consume(.RIGHT_PAREN, "Expect ')' after while condition.");

        const body = try self.statement();

        return try self.allocStmt(.{ .whileStmt = .{
            .condition = condition,
            .body = body,
        } });
    }

    fn ifStmt(self: *Self) ParserFailure!*const Stmt {
        try self.consume(.LEFT_PAREN, "Expect '(' after 'if'.");
        const expr = try self.expression();

        try self.consume(.RIGHT_PAREN, "Expect ')' after if condition.");
        const trueStmt = try self.statement();

        const falseStmt = if (self.match(.ELSE))
            try self.statement()
        else
            null;

        return try self.allocStmt(.{
            .ifStmt = .{
                .condition = expr,
                .thenBranch = trueStmt,
                .elseBranch = falseStmt,
            },
        });
    }

    fn printStatement(self: *Self) ParserFailure!*const Stmt {
        const expr = try self.expression();
        try self.consume(.SEMICOLON, "Expect ';' after expression");

        return self.allocStmt(.{
            .printStmt = .{
                .expr = expr,
            },
        });
    }
    fn expressionStatement(self: *Self) ParserFailure!*const Stmt {
        const expr = try self.expression();
        try self.consume(.SEMICOLON, "Expect ';' after expression");

        return try self.allocStmt(.{ .expression = .{
            .expr = expr,
        } });
    }

    pub fn expression(self: *Self) ParserFailure!*const Expr {
        return try self.assignment();
    }

    fn assignment(self: *Self) ParserFailure!*const Expr {
        try self.enterRecursiveRule();
        defer self.leaveRecursiveRule();

        const expr = try self.equality();
        if (self.match(.EQUAL)) {
            const equals = self.previousUnchecked();
            const value = try self.assignment();
            switch (expr.*) {
                .variable => |variable| {
                    const name = variable.name;
                    return self.allocExpr(.{ .assign = .{
                        .token = name,
                        .value = value,
                    } });
                },
                else => return self.failAt(
                    equals,
                    error.InvalidSyntax,
                    "Invalid assignment target.",
                ),
            }
        }
        return expr;
    }

    fn equality(self: *Self) ParserFailure!*const Expr {
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

    fn comparison(self: *Self) ParserFailure!*const Expr {
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

    fn term(self: *Self) ParserFailure!*const Expr {
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

    fn factor(self: *Self) ParserFailure!*const Expr {
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

    fn unary(self: *Self) ParserFailure!*const Expr {
        try self.enterRecursiveRule();
        defer self.leaveRecursiveRule();

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

    fn primary(self: *Self) ParserFailure!*const Expr {
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
        } else if (self.match(.NIL)) {
            return try self.allocExpr(.{
                .literal = .{
                    .value = .nil,
                },
            });
        } else if (self.match(.NUMBER)) {
            const token = self.previousUnchecked();
            const number = std.fmt.parseInt(i64, token.lexeme, 10) catch |err| switch (err) {
                error.Overflow => return self.failAt(
                    token,
                    error.NumberLiteralOutOfRange,
                    "Number literal is outside the i64 range.",
                ),
                error.InvalidCharacter => unreachable,
            };
            return try self.allocExpr(.{
                .literal = .{
                    .value = .from(number),
                },
            });
        } else if (self.match(.STRING)) {
            const stringLen = self.previousUnchecked().lexeme.len;
            return try self.allocExpr(.{
                .literal = .{
                    .value = .{
                        .string = self.previousUnchecked().lexeme[1 .. stringLen - 1],
                    },
                },
            });
        } else if (self.match(.LEFT_PAREN)) {
            const expr = try self.expression();
            try self.consume(.RIGHT_PAREN, "Expect ')' after expression.");

            return try self.allocExpr(.{
                .grouping = .{
                    .expr = expr,
                },
            });
        } else if (self.match(.IDENTIFIER)) {
            return try self.allocExpr(.{
                .variable = .{
                    .name = self.previousUnchecked(),
                },
            });
        }
        return self.failAtCurrent(
            error.InvalidSyntax,
            "Expect expression.",
        );
    }

    fn consume(self: *Self, tokenType: TokenType, errorMessage: []const u8) ParserFailure!void {
        if (self.match(tokenType)) {
            return;
        }
        return self.failAtCurrent(error.InvalidSyntax, errorMessage);
    }

    fn allocExpr(self: *Self, expr: Expr) ParserFailure!*const Expr {
        const element = try self.alloc.create(Expr);
        element.* = expr;
        return element;
    }

    fn allocStmt(self: *Self, stmt: Stmt) ParserFailure!*const Stmt {
        const element = try self.alloc.create(Stmt);
        element.* = stmt;
        return element;
    }

    fn enterRecursiveRule(self: *Self) ParserError!void {
        if (self.recursion_depth >= max_recursion_depth) {
            return self.failAtCurrent(
                error.NestingTooDeep,
                "Maximum nesting depth exceeded.",
            );
        }
        self.recursion_depth += 1;
    }

    fn leaveRecursiveRule(self: *Self) void {
        std.debug.assert(self.recursion_depth > 0);
        self.recursion_depth -= 1;
    }

    fn failAtCurrent(self: *Self, kind: ParserError, message: []const u8) ParserError {
        if (!self.isAtEnd()) {
            return self.failAt(self.peekUnchecked(), kind, message);
        }

        const line = if (self.tokens.len == 0)
            1
        else
            self.tokens[self.tokens.len - 1].line;

        self.reporter.report(.{
            .stage = .parser,
            .kind = kind,
            .line = line,
            .lexeme = "",
            .at_end = true,
            .message = message,
        });
        return kind;
    }

    fn failAt(self: *Self, token: Token, kind: ParserError, message: []const u8) ParserError {
        self.reporter.report(.{
            .stage = .parser,
            .kind = kind,
            .line = token.line,
            .lexeme = token.lexeme,
            .message = message,
        });
        return kind;
    }
};
