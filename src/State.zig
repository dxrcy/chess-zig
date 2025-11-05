const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

pub const Board = @import("Board.zig");
pub const Tile = Board.Tile;
pub const Piece = Board.Piece;

const moves = @import("moves.zig");

board: Board,
turn: Player,
focus: Tile,
selected: ?Tile,

pub const Player = enum(u8) {
    white = 0,
    black = 1,

    pub fn flip(self: Player) Player {
        return if (self == .white) .black else .white;
    }
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

// TODO: Rename
pub fn toggleSelection(self: *Self, allow_invalid: bool) void {
    const selected = self.selected orelse {
        const piece = self.board.get(self.focus);
        if (piece != null and
            piece.?.player == self.turn)
        {
            self.selected = self.focus;
        }
        return;
    };

    self.selected = null;

    if (self.board.get(selected) == null) {
        return;
    }
    if (selected.eql(self.focus)) {
        return;
    }

    const piece = self.board.get(selected);
    if (piece == null or
        piece.?.player != self.turn)
    {
        return;
    }

    if (allow_invalid) {
        self.board.set(self.focus, piece);
        self.board.set(selected, null);
    }

    const move = self.getAvailableMove(selected, self.focus) orelse
        return;
    assert(move.destination.eql(self.focus));

    if (move.take) |take| {
        const piece_taken = self.board.get(take) orelse unreachable;
        self.board.taken_buffer[self.board.taken_count] = piece_taken;
        self.board.taken_count += 1;

        self.board.set(take, null);
    }

    self.board.set(self.focus, piece);
    self.board.set(selected, null);

    self.turn = self.turn.flip();
}

fn getAvailableMove(self: *const Self, origin: Tile, destination: Tile) ?moves.Move {
    var available_moves = self.board.getAvailableMoves(origin);
    while (available_moves.next()) |available| {
        if (available.destination.eql(destination)) {
            return available;
        }
    }
    return null;
}
