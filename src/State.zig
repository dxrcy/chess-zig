const Self = @This();

const std = @import("std");

pub const Board = @import("Board.zig");

board: Board,
turn: Player,
focus: Position,
selected: ?Position,

pub const Player = enum(u8) {
    white = 0,
    black = 1,
};

pub const Position = struct {
    rank: usize,
    file: usize,

    pub fn eql(lhs: Position, rhs: Position) bool {
        return lhs.rank == rhs.rank and lhs.file == rhs.file;
    }

    pub fn isEven(self: Position) bool {
        return (self.rank + self.file) % 2 == 0;
    }
};

pub fn new() Self {
    return Self{
        .board = Board.new(),
        .turn = .black,
        .focus = .{ .rank = 1, .file = 1 },
        .selected = null,
    };
}

pub fn moveFocus(self: *Self, direction: enum { left, right, up, down }) void {
    switch (direction) {
        .left => if (self.focus.file == 0) {
            self.focus.file = Board.SIZE - 1;
        } else {
            self.focus.file -= 1;
        },
        .right => if (self.focus.file >= Board.SIZE - 1) {
            self.focus.file = 0;
        } else {
            self.focus.file += 1;
        },
        .up => if (self.focus.rank == 0) {
            self.focus.rank = Board.SIZE - 1;
        } else {
            self.focus.rank -= 1;
        },
        .down => if (self.focus.rank >= Board.SIZE - 1) {
            self.focus.rank = 0;
        } else {
            self.focus.rank += 1;
        },
    }
}

pub fn toggleSelection(self: *Self) void {
    if (self.selected == null) {
        self.selected = self.focus;
    } else {
        self.selected = null;
    }
}
