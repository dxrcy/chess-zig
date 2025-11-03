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
/// Most methods do **not** modify this field. eg. [`print`].
state: State,

pub const State = struct {
    cursor: Cursor = .{ .row = 0, .col = 0 },
    style: Style = .{},
    fg: Color = .unset,
    bg: Color = .unset,
};

pub const Cursor = struct {
    row: usize,
    col: usize,
    pub fn eql(lhs: Cursor, rhs: Cursor) bool {
        return lhs.row == rhs.row and lhs.col == rhs.col;
    }
};

pub const Style = packed struct {
    bold: bool = false,
    dim: bool = false,
    italic: bool = false,
};

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

/// State field is initialized with empty values.
pub fn new() Self {
    return Self{
        .original_termios = null,
        .state = State{},
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

pub fn updateState(self: *Self, state: State) bool {
    var any_changed = false;

    if (!state.cursor.eql(self.state.cursor)) {
        self.print("\x1b[{};{}H", .{ state.cursor.row, state.cursor.col });
        any_changed = true;
    }

    // TODO: Support all style attributes
    if (state.style.bold != self.state.style.bold) {
        self.print("\x1b[{d}m", .{@as(u8, if (state.style.bold) 1 else 22)});
        any_changed = true;
    }

    if (state.fg != self.state.fg) {
        self.print("\x1b[3{d}m", .{@intFromEnum(state.fg)});
        any_changed = true;
    }

    if (state.bg != self.state.bg) {
        self.print("\x1b[4{d}m", .{@intFromEnum(state.bg)});
        any_changed = true;
    }

    self.state = state;
    return any_changed;
}

/// Returns `true` if cursor changed.
// TODO: Remove
pub fn updateCursor(self: *Self, cursor: Cursor) bool {
    if (cursor.eql(self.state.cursor)) {
        return false;
    }
    self.print("\x1b[{};{}H", .{ cursor.row, cursor.col });
    self.state.cursor = cursor;
    return true;
}

/// Returns `true` if style attributes changed.
// TODO: Remove
pub fn updateStyle(self: *Self, style: Style) bool {
    var any_changed = false;

    // TODO: Support all attributes
    if (style.bold != self.state.style.bold) {
        any_changed = true;
        self.print("\x1b[{d}m", .{@as(u8, if (style.bold) 1 else 22)});
    }

    if (any_changed) {
        self.state.style = style;
    }
    return any_changed;
}

/// Returns `true` if foreground color changed.
// TODO: Remove
pub fn updateForeground(self: *Self, fg: Color) bool {
    if (fg == self.state.fg) {
        return false;
    }
    self.print("\x1b[3{d}m", .{@intFromEnum(fg)});
    self.state.fg = fg;
    return true;
}

/// Returns `true` if background color changed.
// TODO: Remove
pub fn updateBackground(self: *Self, bg: Color) bool {
    if (bg == self.state.bg) {
        return false;
    }
    self.print("\x1b[4{d}m", .{@intFromEnum(bg)});
    self.state.bg = bg;
    return true;
}
