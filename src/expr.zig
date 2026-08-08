const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Expr = union(enum) {
    assign: Assign,
    binary: Binary,
    call: Call,
    get: Get,
    grouping: Grouping,
    literal: Literal,
    logical: Logical,
    set: Set,
    super: Super,
    this: This,
    unary: Unary,
    variable: Variable,
};

const Assign = struct {
    token: Token,
    value: *Expr,
};

const Binary = struct {
    left: *Expr,
    operator: *Token,
    right: *Expr,
};

const Call = struct {
    callee: *Expr,
    paren: Token,
    arguments: []*Expr,
};

const Get = struct {
    object: *Expr,
    name: Token,
};

const Grouping = struct {
    expression: *Expr,
};

const Literal = struct {
    value: []const u8,
};

const Logical = struct {
    left: *Expr,
    operator: *Token,
    right: *Expr,
};

const Set = struct {
    object: *Expr,
    name: Token,
    value: *Expr,
};

const Super = struct {
    keyword: Token,
    nethod: Token,
};

const This = struct {
    keyword: Token,
};

const Unary = struct {
    operator: Token,
    right: *Expr,
};

const Variable = struct {
    name: Token,
};
