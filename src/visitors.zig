const std = @import("std");
const Expr = @import("expr.zig").Expr;

const AstPrinter = struct {
    const Self = @This();

    alloc: std.mem.Allocator,

    fn init(alloc: std.mem.Allocator) Self {
        return Self{ .alloc = alloc };
    }

    fn visit(self: *Self, expr: *Expr) ![]const u8 {
        const ast = try std.ArrayList(u8).initCapacity(self.alloc, 42);
        _ = ast;

        switch (expr.*) {
            .assign => {},
            .binary => {},
            .call => {},
            .get => {},
            .grouping => {},
            .literal => {},
            .logical => {},
            .set => {},
            .super => {},
            .this => {},
            .unary => {},
            .variable => {},
        }
    }
};
