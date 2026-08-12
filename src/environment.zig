const std = @import("std");
const Value = @import("expr.zig").Value;
const EnvironmentFailure = @import("errors.zig").EnvironmentFailure;
const Warn = @import("warn.zig").Warn;

pub const Environment = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    values: std.StringHashMap(Value),

    enclosing: ?*Environment = null,

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .values = .init(alloc),
        };
    }

    pub fn assign(self: *Self, name: []const u8, value: Value) EnvironmentFailure!void {
        try self.assignEnvironment(name, value);
    }

    pub fn define(self: *Self, name: []const u8, value: Value) EnvironmentFailure!void {
        try self.defineEnvironment(name, value);
    }

    pub fn get(self: *Self, name: []const u8) EnvironmentFailure!Value {
        return self.getEnvironment(name);
    }

    fn getEnvironment(self: *Self, name: []const u8) EnvironmentFailure!Value {
        if (self.values.get(name)) |value| {
            return value;
        }
        if (self.enclosing) |enclosing| {
            return try enclosing.getEnvironment(name);
        }
        return EnvironmentFailure.UndefinedVariable;
    }

    fn defineEnvironment(self: *Self, name: []const u8, value: Value) EnvironmentFailure!void {
        if (self.values.contains(name)) {
            Warn.warn("warning: Variable '{s}' is already declared in this scope.\n", .{name});
        }
        try self.values.put(name, value);
    }

    fn assignEnvironment(self: *Self, name: []const u8, value: Value) EnvironmentFailure!void {
        if (self.values.contains(name)) {
            return try self.values.put(name, value);
        }

        if (self.enclosing) |enclosing| {
            return try enclosing.assignEnvironment(name, value);
        }
        return EnvironmentFailure.UndefinedVariable;
    }
};
