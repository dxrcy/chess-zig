const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

pub const SIZE: usize = 8;

tiles: [SIZE * SIZE]u8,

pub const Piece = enum(u8) {
    pawn = 1,
    rook,
    knight,
    bishop,
    king,
    queen,

    pub const HEIGHT: usize = 3;
    pub const WIDTH: usize = 3;

    /// Returns `HEIGHT*WIDTH` ASCII representation of `self`.
    pub fn string(self: Piece) []const u8 {
        return switch (self) {
            .pawn =>
            \\ _ (_)/_\
            ,
            .rook =>
            \\vvv]_[[_]
            ,
            .knight =>
            \\/'|"/|/_|
            ,
            .bishop =>
            \\(^))_(/_\
            ,
            .king =>
            \\\^/]_[/_\
            ,
            .queen =>
            \\[+])_(/_\
            ,
        };
    }
};

pub fn new() Self {
    var self = Self{
        .tiles = [_]u8{0} ** SIZE ** SIZE,
    };
    for (0..8) |x| {
        self.set(1, x, .pawn);
        self.set(6, x, .pawn);
    }
    for ([2]usize{ 0, 7 }) |y| {
        self.set(y, 0, .rook);
        self.set(y, 1, .knight);
        self.set(y, 2, .bishop);
        self.set(y, 3, .king);
        self.set(y, 4, .queen);
        self.set(y, 5, .bishop);
        self.set(y, 6, .knight);
        self.set(y, 7, .rook);
    }
    return self;
}

pub fn get(self: *const Self, row: usize, col: usize) ?Piece {
    assert(row < SIZE);
    assert(col < SIZE);

    const value = self.tiles[row * SIZE + col];
    if (value == 0) {
        return null;
    }
    return @enumFromInt(value);
}

pub fn set(self: *Self, row: usize, col: usize, piece: ?Piece) void {
    assert(row < SIZE);
    assert(col < SIZE);

    const value = if (piece) |piece_unwrapped|
        @intFromEnum(piece_unwrapped)
    else
        0;
    self.tiles[row * SIZE + col] = value;
}
