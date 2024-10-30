const std = @import("std");
const mem = std.mem;
const log = std.log.scoped(.lexer);

const Tokens = @import("token.zig");
const Token = Tokens.Token;
const TokenType = Tokens.TokenType;

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

    pub fn eof(self: *Self) bool {
        return self.current_pos >= self.source.len - 1;
    }

    pub fn is_whitespace(self: *Self) bool {
        return std.ascii.isWhitespace(self.source[self.current_pos]);
    }

    pub fn is_char_at(self: *Self, c: u8, index: usize) bool {
        return self.source[index] == c;
    }

    pub fn chop_char(self: *Self) ?u8 {
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
            // Some html tag
            if (c == '<') {
                // Doctype decl
                if (self.is_char_at('!', self.current_pos)) {
                    self.current_pos += 1;
                    const token = Tokens.forDocTypeDecl(self);
                    try self.tokens.append(token);
                    continue :outer;
                }

                // Closing Tag
                if (self.is_char_at('/', self.current_pos)) {
                    self.current_pos += 1;
                    const token = Tokens.forClosingTag(self);
                    try self.tokens.append(token);
                    continue :outer;
                }

                // Opening Tag
                const token = Tokens.forOpeningTag(self);
                try self.tokens.append(token);

                continue :outer;
            }

            // Opening or Closing tag end can be followed
            // by arbitrary text
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
