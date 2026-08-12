const std = @import("std");
const Value = @import("expr.zig").Value;
const EnvironmentError = @import("errors.zig").EnvironmentError;

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

    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn assign(self: *Self, name: []const u8, value: Value) EnvironmentError!void {
        try self.assignEnvironment(name, value);
    }

    pub fn define(self: *Self, name: []const u8, value: Value) std.mem.Allocator.Error!bool {
        return self.defineEnvironment(name, value);
    }

    pub fn get(self: *Self, name: []const u8) EnvironmentError!Value {
        return self.getEnvironment(name);
    }

    fn getEnvironment(self: *Self, name: []const u8) EnvironmentError!Value {
        if (self.values.get(name)) |value| {
            return value;
        }
        if (self.enclosing) |enclosing| {
            return try enclosing.getEnvironment(name);
        }
        return EnvironmentError.UndefinedVariable;
    }

    fn defineEnvironment(self: *Self, name: []const u8, value: Value) std.mem.Allocator.Error!bool {
        const already_defined = self.values.contains(name);
        try self.values.put(name, value);
        return already_defined;
    }

    fn assignEnvironment(self: *Self, name: []const u8, value: Value) EnvironmentError!void {
        if (self.values.getPtr(name)) |stored| {
            stored.* = value;
            return;
        }

        if (self.enclosing) |enclosing| {
            return try enclosing.assignEnvironment(name, value);
        }
        return EnvironmentError.UndefinedVariable;
    }
};
