const Self = @This();

const std = @import("std");
const assert = std.debug.assert;
const posix = std.posix;

original_termios: ?posix.termios,

pub fn new() Self {
    return Self{
        .original_termios = null,
    };
}

pub fn saveTermios(self: *Self) !void {
    if (self.original_termios != null) {
        std.debug.panic("tried to save termios twice", .{});
    }
    self.original_termios = try posix.tcgetattr(posix.STDIN_FILENO);
}

pub fn restoreTermios(self: *Self) !void {
    const termios = self.original_termios orelse {
        std.debug.panic("tried to restore termios before saving", .{});
    };
    try posix.tcsetattr(posix.STDIN_FILENO, .NOW, termios);
    self.original_termios = null;
}

pub fn setAlternativeScreen(self: *Self, state: enum { enter, exit }) void {
    _ = self;
    std.debug.print("\x1b[?1049{c}", .{
        @as(u8, if (state == .enter) 'h' else 'l'),
    });
}

pub fn setCursorVisibility(self: *Self, state: enum { visible, hidden }) void {
    _ = self;
    std.debug.print("\x1b[?25{c}", .{
        @as(u8, if (state == .visible) 'h' else 'l'),
    });
}

pub fn clearScreen(self: *Self) void {
    _ = self;
    std.debug.print("\x1b[J", .{});
}

pub fn setCursorPosition(self: *Self, row: u16, col: u16) void {
    _ = self;
    std.debug.print("\x1b[{};{}H", .{ row, col });
}
