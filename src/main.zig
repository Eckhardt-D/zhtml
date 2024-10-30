const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

/// Ten Megabytes (MibiBytes)
const MAX_FILE_SIZE = 10 * 1024 * 1024;

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa_impl.allocator();

    const cwd = std.fs.cwd();
    const fd = try cwd.openFile("fixtures/test.html", .{ .mode = .read_only });
    defer fd.close();

    const source = try fd.readToEndAlloc(allocator, MAX_FILE_SIZE);
    defer allocator.free(source);

    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.lex();

    for (lexer.tokens.items) |token| {
        std.debug.print("{?s} -> {s}\n", .{ token.value, @tagName(token.type) });
    }
}
