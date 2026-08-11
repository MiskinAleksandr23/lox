const std = @import("std");
const run = @import("run.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    var args = init.minimal.args.iterate();
    _ = args.skip();

    const path = args.next().?[0..];

    run.runFile(io, allocator, path[0..]) catch |err| {
        std.debug.print("Compilation failed with: {}\n", .{err});
    };
}
