const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

const State = @import("State.zig");
const Player = State.Player;

const moves = @import("moves.zig");

pub const SIZE: usize = 8;

tiles: [SIZE * SIZE]u8,

pub fn new() Self {
    var self = Self{
        .tiles = [_]u8{0} ** SIZE ** SIZE,
    };
    for (0..8) |file| {
        self.set(.{ .rank = 1, .file = file }, .{ .kind = .pawn, .player = .white });
        self.set(.{ .rank = 6, .file = file }, .{ .kind = .pawn, .player = .black });
    }
    for ([2]usize{ 0, 7 }, [2]Player{ .white, .black }) |rank, player| {
        self.set(.{ .rank = rank, .file = 0 }, .{ .kind = .rook, .player = player });
        self.set(.{ .rank = rank, .file = 1 }, .{ .kind = .knight, .player = player });
        self.set(.{ .rank = rank, .file = 2 }, .{ .kind = .bishop, .player = player });
        self.set(.{ .rank = rank, .file = 3 }, .{ .kind = .king, .player = player });
        self.set(.{ .rank = rank, .file = 4 }, .{ .kind = .queen, .player = player });
        self.set(.{ .rank = rank, .file = 5 }, .{ .kind = .bishop, .player = player });
        self.set(.{ .rank = rank, .file = 6 }, .{ .kind = .knight, .player = player });
        self.set(.{ .rank = rank, .file = 7 }, .{ .kind = .rook, .player = player });
    }
    return self;
}

pub fn get(self: *const Self, tile: Tile) ?Piece {
    assert(tile.rank < SIZE);
    assert(tile.file < SIZE);

    const value = self.tiles[tile.rank * SIZE + tile.file];
    if (value == 0) {
        return null;
    }
    return Piece.fromInt(value);
}

pub fn set(self: *Self, tile: Tile, piece: ?Piece) void {
    assert(tile.rank < SIZE);
    assert(tile.file < SIZE);

    const value = if (piece) |piece_unwrapped|
        piece_unwrapped.toInt()
    else
        0;
    self.tiles[tile.rank * SIZE + tile.file] = value;
}

pub const Tile = struct {
    rank: usize,
    file: usize,

    pub fn eql(lhs: Tile, rhs: Tile) bool {
        return lhs.rank == rhs.rank and lhs.file == rhs.file;
    }

    pub fn isEven(self: Tile) bool {
        return (self.rank + self.file) % 2 == 0;
    }
};

pub const Piece = struct {
    kind: Kind,
    player: Player,

    pub const Kind = enum(u8) {
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

pub fn getAvailableMoves(board: *const Self, origin: Tile) moves.AvailableMoves {
    return moves.AvailableMoves.new(board, origin);
}
