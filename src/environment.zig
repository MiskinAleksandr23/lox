const std = @import("std");
const Value = @import("expr.zig").Value;
const InterpreterFailure = @import("errors.zig").InterpreterFailure;

pub const Environment = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    values: std.StringHashMap(Value),
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .values = .init(alloc),
        };
    }

    pub fn define(self: *Self, name: []const u8, value: Value) InterpreterFailure!void {
        try self.values.put(name, value);
    }

    pub fn get(self: *Self, name: []const u8) InterpreterFailure!Value {
        if (self.values.get(name)) |value| {
            return value;
        } else {
            return InterpreterFailure.UnknownIdentifier;
        }
    }
};
