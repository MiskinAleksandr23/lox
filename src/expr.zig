const Token = @import("token.zig").Token;

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

pub const Assign = struct {
    token: Token,
    value: *const Expr,
};

pub const Binary = struct {
    left: *const Expr,
    operator: Token,
    right: *const Expr,
};

pub const Call = struct {
    callee: *const Expr,
    paren: Token,
    arguments: []*const Expr,
};

pub const Get = struct {
    object: *const Expr,
    name: Token,
};

pub const Grouping = struct {
    expr: *const Expr,
};

const LiteralValue = union(enum) {
    boolean: bool,
    integer: i64,
    string: []const u8,
};

pub const Literal = struct {
    value: LiteralValue,
};

pub const Logical = struct {
    left: *const Expr,
    operator: Token,
    right: *const Expr,
};

pub const Set = struct {
    object: *const Expr,
    name: Token,
    value: *const Expr,
};

pub const Super = struct {
    keyword: Token,
    nethod: Token,
};

pub const This = struct {
    keyword: Token,
};

pub const Unary = struct {
    operator: Token,
    right: *const Expr,
};

pub const Variable = struct {
    name: Token,
};
