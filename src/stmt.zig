const Token = @import("token.zig").Token;
const Variable = @import("expr.zig").Variable;
const Expr = @import("expr.zig").Expr;

pub const Stmt = union(enum) {
    block: Block,
    class: Class,
    expression: Expression,
    function: Function,
    ifStmt: IfStmt,
    printStmt: PrintStmt,
    returnStmt: ReturnStmt,
    varStmt: VarStmt,
    whileStmt: WhileStmt,
};

pub const Block = struct {
    statements: []*const Stmt,
};

pub const Class = struct {
    name: Token,
    superclass: Variable,
    methods: []const Function,
};

pub const Function = struct {
    name: Token,
    params: []const Token,
    body: []*const Stmt,
};

pub const Expression = struct {
    expr: *const Expr,
};

pub const IfStmt = struct {
    condition: *const Expr,
    thenBranch: *const Stmt,
    elseBranch: *const Stmt,
};

pub const PrintStmt = struct {
    expr: *const Expr,
};

pub const ReturnStmt = struct {
    keyword: Token,
    value: *const Expr,
};

pub const VarStmt = struct {
    name: Token,
    initializer: *const Expr,
};

pub const WhileStmt = struct {
    condition: *const Expr,
    body: *const Stmt,
};
