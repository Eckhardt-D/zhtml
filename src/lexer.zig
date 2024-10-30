const std = @import("std");
const mem = std.mem;

const Tokens = @import("token.zig");
const Token = Tokens.Token;
const TokenType = Tokens.TokenType;

fn is_self_closing(identifier: []const u8) bool {
    const self_closing_tags = [_][]const u8{
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr",
    };

    inline for (self_closing_tags) |tag| {
        if (mem.eql(u8, identifier, tag)) {
            return true;
        }
    }

    return false;
}

pub const Lexer = struct {
    allocator: mem.Allocator,
    tokens: std.ArrayList(Token),
    source: []u8,
    line_begin: usize = 0,
    current_pos: usize = 0,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, source: []u8) Lexer {
        return .{
            .allocator = allocator,
            .tokens = std.ArrayList(Token).init(allocator),
            .source = source,
        };
    }

    fn eof(self: *Self) bool {
        return self.current_pos >= self.source.len - 1;
    }

    fn is_whitespace(self: *Self) bool {
        return std.ascii.isWhitespace(self.source[self.current_pos]);
    }

    fn is_char_at(self: *Self, c: u8, index: usize) bool {
        return self.source[index] == c;
    }

    fn chop_char(self: *Self) ?u8 {
        if (self.eof()) {
            return null;
        }

        while (!self.eof() and self.is_whitespace()) {
            if (self.is_char_at('\n', self.current_pos)) {
                self.line_begin = self.current_pos;
            }

            self.current_pos += 1;
        }

        const previous_pos = self.current_pos;
        self.current_pos += 1;
        return self.source[previous_pos];
    }

    pub fn lex(self: *Self) !void {
        outer: while (self.chop_char()) |c| {
            if (c == '<') {
                // Doctype decl
                if (self.is_char_at('!', self.current_pos)) {
                    self.current_pos += 1;
                    const start = self.current_pos;
                    const doctype: []const u8 = "DOCTYPE";
                    const slice: []const u8 = self.source[start .. start + doctype.len];

                    if (std.mem.eql(u8, slice, doctype)) {
                        self.current_pos += doctype.len;
                        while (!self.eof() and !self.is_char_at('>', self.current_pos)) {
                            if (self.is_char_at('\n', self.current_pos)) {
                                @panic("Unexpected newline in doctype declaration\n");
                            }
                            self.current_pos += 1;
                        }
                        try self.tokens.append(Token{
                            .start = start - 2, // '<!' already consumed,
                            .end = self.current_pos,
                            .type = TokenType.DoctypeDecl,
                            .value = null,
                        });

                        continue :outer;
                    }
                }

                if (self.is_char_at('/', self.current_pos)) {
                    self.current_pos += 1;
                    const start = self.current_pos;
                    while (!self.eof() and !self.is_char_at('>', self.current_pos)) {
                        if (self.is_char_at('\n', self.current_pos)) {
                            @panic("Unexpected newline in closing tag\n");
                        }
                        self.current_pos += 1;
                    }

                    try self.tokens.append(Token{
                        .start = start, // '<' already consumed,
                        .end = self.current_pos,
                        .type = TokenType.CloseTag,
                        .value = self.source[start..self.current_pos],
                    });

                    continue :outer;
                }

                if (!std.ascii.isAlphanumeric(self.source[self.current_pos])) {
                    std.debug.panic("Expected identifier after '<', found {c}\n", .{self.source[self.current_pos]});
                }

                const start = self.current_pos;
                while (std.ascii.isAlphanumeric(self.source[self.current_pos])) {
                    self.current_pos += 1;
                }

                if (self.eof()) {
                    std.debug.panic("Unexpected EOF\n", .{});
                }

                const end = self.current_pos;
                const identifier = self.source[start..end];

                if (is_self_closing(identifier)) {
                    try self.tokens.append(Token{
                        .start = start,
                        .end = end,
                        .type = TokenType.SelfClosingTag,
                        .value = identifier,
                    });
                    continue :outer;
                }

                try self.tokens.append(Token{
                    .start = start,
                    .end = end,
                    .type = TokenType.OpenTag,
                    .value = identifier,
                });

                continue :outer;
            }

            if (c == '>') {
                const start = self.current_pos;
                while (!self.eof() and !self.is_char_at('<', self.current_pos)) {
                    self.current_pos += 1;
                }

                const trimmed = std.mem.trim(u8, self.source[start..self.current_pos], &std.ascii.whitespace);

                if (trimmed.len == 0) {
                    continue :outer;
                }

                try self.tokens.append(Token{
                    .start = start,
                    .end = self.current_pos,
                    .type = TokenType.Text,
                    .value = trimmed,
                });
                continue :outer;
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
        self.line_begin = 0;
        self.current_pos = 0;
    }
};
