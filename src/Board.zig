const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

const State = @import("State.zig");
const Player = State.Player;

pub const SIZE: usize = 8;

tiles: [SIZE * SIZE]u8,

pub fn new() Self {
    var self = Self{
        .tiles = [_]u8{0} ** SIZE ** SIZE,
    };
    for (0..8) |x| {
        self.set(.{ .rank = 1, .file = x }, .{ .kind = .pawn, .player = .white });
        self.set(.{ .rank = 6, .file = x }, .{ .kind = .pawn, .player = .black });
    }
    for ([2]usize{ 0, 7 }, [2]Player{ .white, .black }) |y, player| {
        self.set(.{ .rank = y, .file = 0 }, .{ .kind = .rook, .player = player });
        self.set(.{ .rank = y, .file = 1 }, .{ .kind = .knight, .player = player });
        self.set(.{ .rank = y, .file = 2 }, .{ .kind = .bishop, .player = player });
        self.set(.{ .rank = y, .file = 3 }, .{ .kind = .king, .player = player });
        self.set(.{ .rank = y, .file = 4 }, .{ .kind = .queen, .player = player });
        self.set(.{ .rank = y, .file = 5 }, .{ .kind = .bishop, .player = player });
        self.set(.{ .rank = y, .file = 6 }, .{ .kind = .knight, .player = player });
        self.set(.{ .rank = y, .file = 7 }, .{ .kind = .rook, .player = player });
    }
    return self;
}

pub fn get(self: *const Self, position: Position) ?Piece {
    assert(position.rank < SIZE);
    assert(position.file < SIZE);

    const value = self.tiles[position.rank * SIZE + position.file];
    if (value == 0) {
        return null;
    }
    return Piece.fromInt(value);
}

pub fn set(self: *Self, position: Position, piece: ?Piece) void {
    assert(position.rank < SIZE);
    assert(position.file < SIZE);

    const value = if (piece) |piece_unwrapped|
        piece_unwrapped.toInt()
    else
        0;
    self.tiles[position.rank * SIZE + position.file] = value;
}

// TODO: Rename `Tile`
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
