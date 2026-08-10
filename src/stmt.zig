const Token = @import("token.zig").Token;
const Variable = @import("expr.zig").Variable;
const Expr = @import("expr.zig").Expr;

pub const Stmt = union(enum) {
    block: Block,
    class: Class,
    expr: Expression,
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
    expr: Expr,
};

pub const IfStmt = struct {
    condition: Expr,
    thenBranch: *const Stmt,
    elseBranch: *const Stmt,
};

pub const PrintStmt = struct {
    expr: Expr,
};

pub const ReturnStmt = struct {
    keyword: Token,
    value: Expr,
};

pub const VarStmt = struct {
    name: Token,
    initializer: Expr,
};

pub const WhileStmt = struct {
    condition: Expr,
    body: *const Stmt,
};
