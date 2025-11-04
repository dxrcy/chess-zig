const Self = @This();

const std = @import("std");

pub const Board = @import("Board.zig");
pub const Tile = Board.Tile;
pub const Piece = Board.Piece;

board: Board,
turn: Player,
focus: Tile,
selected: ?Tile,

pub const Player = enum(u8) {
    white = 0,
    black = 1,
};

pub fn new() Self {
    return Self{
        .board = Board.new(),
        .turn = .black,
        .focus = .{ .rank = 3, .file = 3 },
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
    const selected = self.selected orelse {
        if (self.board.get(self.focus) != null) {
            self.selected = self.focus;
        }
        return;
    };

    self.selected = null;

    if (self.board.get(selected) == null) {
        return;
    }

    const temp = self.board.get(self.focus);
    self.board.set(self.focus, self.board.get(selected));
    self.board.set(selected, temp);
}
