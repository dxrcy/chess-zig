const Self = @This();

const std = @import("std");
const assert = std.debug.assert;
const panic = std.debug.panic;
const posix = std.posix;

const stdout = struct {
    const fs = std.fs;

    const BUFFER_SIZE = 1024;

    const FILE = fs.File.stdout();
    var WRITER: ?fs.File.Writer = null;
    var BUFFER: [BUFFER_SIZE]u8 = undefined;

    /// Lazily initializes global writer.
    pub fn writer() *fs.File.Writer {
        if (WRITER == null) {
            WRITER = FILE.writer(&BUFFER);
        }
        return &(WRITER orelse unreachable);
    }
};

original_termios: ?posix.termios,
/// Most methods do **not** modify this field. Eg. [`print`].
cursor: Cursor,
/// Most methods do **not** modify this field. Eg. [`print`].
attributes: Attributes,

pub const Cursor = struct {
    row: usize,
    col: usize,

    pub fn eql(lhs: Cursor, rhs: Cursor) bool {
        return lhs.row == rhs.row and lhs.col == rhs.col;
    }
};

pub const Attributes = struct {
    fg: Color = .unset,
    bg: Color = .unset,
    style: Style = .{},

    /// Use [`Color.unset`] for default color.
    // TODO: Add bright colors
    pub const Color = enum(u8) {
        black = 0,
        red = 1,
        green = 2,
        yellow = 3,
        blue = 4,
        magenta = 5,
        cyan = 6,
        white = 7,
        unset = 9,
    };

    pub const Style = packed struct {
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,

        pub fn eql(lhs: Style, rhs: Style) bool {
            return lhs.bold == rhs.bold and
                lhs.dim == rhs.dim and
                lhs.italic == rhs.italic;
        }
    };

    pub fn eql(lhs: Attributes, rhs: Attributes) bool {
        return lhs.fg == rhs.fg and
            lhs.bg == rhs.bg and
            lhs.style.eql(rhs.style);
    }
};

pub fn new() Self {
    return Self{
        .original_termios = null,
        .cursor = .{ .row = 0, .col = 0 },
        .attributes = Attributes{},
    };
}

pub fn saveTermios(self: *Self) !void {
    if (self.original_termios != null) {
        panic("tried to save termios twice", .{});
    }
    self.original_termios = try posix.tcgetattr(posix.STDIN_FILENO);
}

pub fn restoreTermios(self: *Self) !void {
    const termios = self.original_termios orelse {
        panic("tried to restore termios before saving", .{});
    };
    try self.setTermios(termios);
    self.original_termios = null;
}

// TODO: Rename or something .. misleading names!
pub fn getTermios(self: *Self) ?posix.termios {
    return self.original_termios;
}

pub fn setTermios(self: *Self, termios: posix.termios) !void {
    _ = self;
    try posix.tcsetattr(posix.STDIN_FILENO, .NOW, termios);
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
    _ = self;
    stdout.writer().interface.print(fmt, args) catch |err| {
        panic("failed to write to stdout: {}", .{err});
    };
}

pub fn flush(self: *Self) void {
    _ = self;
    stdout.writer().interface.flush() catch |err| {
        panic("failed to flush stdout: {}", .{err});
    };
}

pub fn setAlternativeScreen(self: *Self, state: enum { enter, exit }) void {
    self.print("\x1b[?1049{c}", .{
        @as(u8, if (state == .enter) 'h' else 'l'),
    });
}

pub fn setCursorVisibility(self: *Self, state: enum { visible, hidden }) void {
    self.print("\x1b[?25{c}", .{
        @as(u8, if (state == .visible) 'h' else 'l'),
    });
}

pub fn clearEntireScreen(self: *Self) void {
    self.print("\x1b[2J", .{});
}

/// Returns `true` if cursor changed.
pub fn updateCursor(self: *Self, cursor: Cursor) bool {
    if (cursor.eql(self.cursor)) {
        return false;
    }
    self.print("\x1b[{};{}H", .{ cursor.row, cursor.col });
    self.cursor = cursor;
    return true;
}

/// Returns `true` if any attributes changed.
pub fn updateAttributes(self: *Self, attributes: Attributes) bool {
    var any_changed = false;

    if (attributes.fg != self.attributes.fg) {
        self.print("\x1b[3{d}m", .{@intFromEnum(attributes.fg)});
        any_changed = true;
    }

    if (attributes.bg != self.attributes.bg) {
        self.print("\x1b[4{d}m", .{@intFromEnum(attributes.bg)});
        any_changed = true;
    }

    // TODO: Support all style attributes
    if (attributes.style.bold != self.attributes.style.bold) {
        self.print("\x1b[{d}m", .{@as(u8, if (attributes.style.bold) 1 else 22)});
        any_changed = true;
    }

    self.attributes = attributes;
    return any_changed;
}
