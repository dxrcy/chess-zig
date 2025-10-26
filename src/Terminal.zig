const Self = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const panic = std.debug.panic;
const posix = std.posix;

stdout: fs.File,
original_termios: ?posix.termios,

pub const Style = enum(u8) {
    bold = 1,
    dim = 2,
    italic = 3,
};

pub const Color = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
};

pub fn new() Self {
    return Self{
        .stdout = fs.File.stdout(),
        .original_termios = null,
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
    var buffer: [1]u8 = undefined;
    var writer = self.stdout.writer(&buffer);
    writer.interface.print(fmt, args) catch |err| {
        panic("failed to write to stdout: {}", .{err});
    };
    writer.interface.flush() catch |err| {
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

pub fn clearScreen(self: *Self) void {
    self.print("\x1b[J", .{});
}

pub fn setCursorPosition(self: *Self, row: u16, col: u16) void {
    self.print("\x1b[{};{}H", .{ row, col });
}

pub fn resetStyle(self: *Self) void {
    self.print("\x1b[0m", .{});
}

pub fn setStyle(self: *Self, style: Style) void {
    self.print("\x1b[{d}m", .{@intFromEnum(style)});
}

pub fn setForeground(self: *Self, color: Color) void {
    self.print("\x1b[3{d}m", .{@intFromEnum(color)});
}

pub fn setBackground(self: *Self, color: Color) void {
    self.print("\x1b[4{d}m", .{@intFromEnum(color)});
}
