const std = @import("std");
const Value = @import("expr.zig").Value;
const InterpreterFailure = @import("errors.zig").InterpreterFailure;

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

    pub fn assign(self: *Self, name: []const u8, value: Value) InterpreterFailure!void {
        try self.assignEnvironment(name, value);
    }

    pub fn define(self: *Self, name: []const u8, value: Value) InterpreterFailure!void {
        try self.defineEnvironment(name, value);
    }

    pub fn get(self: *Self, name: []const u8) InterpreterFailure!Value {
        return self.getEnvironment(name);
    }

    fn getEnvironment(self: *Self, name: []const u8) InterpreterFailure!Value {
        if (self.values.get(name)) |value| {
            return value;
        } else {
            if (self.enclosing) |en| {
                return try en.getEnvironment(name);
            } else {
                return InterpreterFailure.UnknownIdentifier;
            }
        }
    }

    fn defineEnvironment(self: *Self, name: []const u8, value: Value) InterpreterFailure!void {
        try self.values.put(name, value); // Report exists?
    }

    fn assignEnvironment(self: *Self, name: []const u8, value: Value) InterpreterFailure!void {
        if (self.values.contains(name)) {
            try self.values.put(name, value);
        } else {
            if (self.enclosing) |en| {
                return try en.assignEnvironment(name, value);
            } else {
                return InterpreterFailure.UnknownIdentifier;
            }
        }
    }
};
