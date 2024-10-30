const std = @import("std");
const meta = std.meta;

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
