const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

const State = @import("State.zig");
const Player = State.Player;

pub const SIZE: usize = 8;

tiles: [SIZE * SIZE]u8,

pub const Piece = struct {
    kind: Kind,
    player: Player,

    const Kind = enum(u8) {
        pawn = 1,
        rook,
        knight,
        bishop,
        king,
        queen,
    };

    pub const HEIGHT: usize = 3;
    pub const WIDTH: usize = 3;

    /// Returns `HEIGHT*WIDTH` ASCII representation of `self`.
    pub fn string(self: Piece) []const u8 {
        return switch (self.kind) {
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

    pub fn fromInt(value: u8) Piece {
        return Piece{
            .kind = @enumFromInt(value & 0b111),
            .player = @enumFromInt(value >> 3),
        };
    }

    pub fn toInt(self: Piece) u8 {
        return @intFromEnum(self.kind) +
            (@intFromEnum(self.player) << 3);
    }
};

pub fn new() Self {
    var self = Self{
        .tiles = [_]u8{0} ** SIZE ** SIZE,
    };
    for (0..8) |x| {
        self.set(1, x, .{ .kind = .pawn, .player = .white });
        self.set(6, x, .{ .kind = .pawn, .player = .black });
    }
    for ([2]usize{ 0, 7 }, [2]Player{ .white, .black }) |y, player| {
        self.set(y, 0, .{ .kind = .rook, .player = player });
        self.set(y, 1, .{ .kind = .knight, .player = player });
        self.set(y, 2, .{ .kind = .bishop, .player = player });
        self.set(y, 3, .{ .kind = .king, .player = player });
        self.set(y, 4, .{ .kind = .queen, .player = player });
        self.set(y, 5, .{ .kind = .bishop, .player = player });
        self.set(y, 6, .{ .kind = .knight, .player = player });
        self.set(y, 7, .{ .kind = .rook, .player = player });
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

    return Piece.fromInt(value);
}

pub fn set(self: *Self, row: usize, col: usize, piece: ?Piece) void {
    assert(row < SIZE);
    assert(col < SIZE);

    const value = if (piece) |piece_unwrapped|
        piece_unwrapped.toInt()
    else
        0;
    self.tiles[row * SIZE + col] = value;
}
