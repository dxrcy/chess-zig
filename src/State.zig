const Self = @This();

const std = @import("std");

pub const Board = @import("Board.zig");

board: Board,
active: Player,
cursor: Position,

pub const Player = enum {
    white,
    black,
};

pub const Position = struct {
    row: usize,
    col: usize,

    pub fn eql(lhs: Position, rhs: Position) bool {
        return lhs.row == rhs.row and lhs.col == rhs.col;
    }
};

pub fn new() Self {
    return Self{
        .board = Board.new(),
        .cursor = .{ .row = 1, .col = 1 },
        .active = .black,
    };
}

pub fn move(self: *Self, direction: enum { left, right, up, down }) void {
    switch (direction) {
        .left => if (self.cursor.col == 0) {
            self.cursor.col = Board.SIZE - 1;
        } else {
            self.cursor.col -= 1;
        },
        .right => if (self.cursor.col >= Board.SIZE - 1) {
            self.cursor.col = 0;
        } else {
            self.cursor.col += 1;
        },
        .up => if (self.cursor.row == 0) {
            self.cursor.row = Board.SIZE - 1;
        } else {
            self.cursor.row -= 1;
        },
        .down => if (self.cursor.row >= Board.SIZE - 1) {
            self.cursor.row = 0;
        } else {
            self.cursor.row += 1;
        },
    }
}
