const std = @import("std");
const meta = std.meta;
const mem = std.mem;
const log = std.log.scoped(.token);
const exit = std.process.exit;

const Lexer = @import("lexer.zig").Lexer;

pub const TokenType = enum(u32) {
    DoctypeDecl,
    OpenTag,
    CloseTag,
    SelfClosingTag,
    Text,
    Attribute,
    AttributeValue,
    Comment,
};

pub const Token = struct {
    type: TokenType,
    value: ?[]const u8,
    start: usize,
    end: usize,
};

pub fn forDocTypeDecl(lexer: *Lexer) Token {
    std.debug.assert(lexer.source[lexer.current_pos - 1] == '!');

    const start = lexer.current_pos;
    const doctype: []const u8 = "DOCTYPE";
    const slice: []const u8 = lexer.source[start .. start + doctype.len];

    if (std.mem.eql(u8, slice, doctype)) {
        lexer.current_pos += doctype.len;

        while (!lexer.eof() and !lexer.is_char_at('>', lexer.current_pos)) {
            lexer.current_pos += 1;

            if (lexer.is_char_at('<', lexer.current_pos)) {
                log.err("Unexpected '<' in DOCTYPE declaration, did you close the tag?\n", .{});
                exit(1);
            }
        }

        if (lexer.eof()) {
            log.err("Unexpected EOF\n", .{});
            exit(1);
        }

        return Token{
            .start = start - 2, // '<!' already consumed,
            .end = lexer.current_pos,
            .type = TokenType.DoctypeDecl,
            .value = null,
        };
    }

    log.err("Unexpected token {s}\n", .{slice});
    exit(1);
}

pub fn forOpeningTag(lexer: *Lexer) Token {
    // Opening tag has no name
    if (!std.ascii.isAlphanumeric(lexer.source[lexer.current_pos])) {
        log.err("Expected identifier after '<', found {c}\n", .{lexer.source[lexer.current_pos]});
        exit(1);
    }

    // Process the tag name
    const start = lexer.current_pos;
    while (!lexer.eof() and std.ascii.isAlphanumeric(lexer.source[lexer.current_pos])) {
        lexer.current_pos += 1;
    }

    if (lexer.eof()) {
        log.err("Unexpected EOF\n", .{});
        exit(1);
    }

    const end = lexer.current_pos;
    const identifier = lexer.source[start..end];

    // Attributes come here, skipped for now
    while (!lexer.eof() and !lexer.is_char_at('>', lexer.current_pos)) {
        if (lexer.is_char_at('<', lexer.current_pos)) {
            log.err("Unexpected '<' in <{s}, did you forget to close the tag?\n", .{identifier});
            exit(1);
        }

        lexer.current_pos += 1;
    }

    if (lexer.eof()) {
        log.err("Unexpected EOF\n", .{});
        exit(1);
    }

    if (is_self_closing(identifier)) {
        return Token{
            .start = start,
            .end = end,
            .type = TokenType.SelfClosingTag,
            .value = identifier,
        };
    }

    return Token{
        .start = start,
        .end = end,
        .type = TokenType.OpenTag,
        .value = identifier,
    };
}

pub fn forClosingTag(lexer: *Lexer) Token {
    std.debug.assert(lexer.source[lexer.current_pos - 1] == '/');
    const start = lexer.current_pos;

    while (!lexer.eof() and !lexer.is_char_at('>', lexer.current_pos)) {
        if (!std.ascii.isAlphanumeric(lexer.source[lexer.current_pos])) {
            log.err("Expected closing identifier after '</{s}'\n", .{lexer.source[start..lexer.current_pos]});
            exit(1);
        }

        lexer.current_pos += 1;
    }

    if (lexer.eof()) {
        log.err("Unexpected EOF\n", .{});
        exit(1);
    }

    const identifier = lexer.source[start..lexer.current_pos];

    if (identifier.len == 0) {
        log.err("Expected identifier after '</'\n", .{});
        exit(1);
    }

    return Token{
        .start = start, // '<' already consumed,
        .end = lexer.current_pos,
        .type = TokenType.CloseTag,
        .value = lexer.source[start..lexer.current_pos],
    };
}

pub fn is_self_closing(identifier: []const u8) bool {
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
