const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

const State = @import("State.zig");
const Player = State.Player;

const moves = @import("moves.zig");

pub const SIZE: usize = 8;
pub const MAX_PIECE_COUNT: usize = SIZE * 2 * Player.COUNT;

tiles: [SIZE * SIZE]u8,
taken: [Piece.Kind.COUNT * Player.COUNT]u32,

pub fn new() Self {
    var self = Self{
        .tiles = [_]u8{0} ** SIZE ** SIZE,
        .taken = [1]u32{0} ** (Piece.Kind.COUNT * Player.COUNT),
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
    return Piece.fromInt(value - 1);
}

pub fn set(self: *Self, tile: Tile, piece: ?Piece) void {
    assert(tile.rank < SIZE);
    assert(tile.file < SIZE);

    const value = if (piece) |piece_unwrapped|
        piece_unwrapped.toInt() + 1
    else
        0;
    self.tiles[tile.rank * SIZE + tile.file] = value;
}

pub fn getTaken(self: *const Self, piece: Piece) u32 {
    return self.taken[piece.toInt()];
}

pub fn addTaken(self: *Self, piece: Piece) void {
    self.taken[piece.toInt()] += 1;
}

pub fn isPieceAlive(self: *const Self, target: Piece) bool {
    for (0..SIZE) |rank| {
        for (0..SIZE) |file| {
            const piece = self.get(.{ .rank = rank, .file = file }) orelse
                continue;
            if (piece.eql(target)) {
                return true;
            }
        }
    }
    return false;
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

    pub const Kind = enum(u3) {
        pawn,
        rook,
        knight,
        bishop,
        king,
        queen,

        pub const COUNT: u8 = @typeInfo(Kind).@"enum".fields.len;
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

    pub fn eql(lhs: Piece, rhs: Piece) bool {
        return lhs.kind == rhs.kind and lhs.player == rhs.player;
    }

    pub fn fromInt(value: u8) Piece {
        return Piece{
            .kind = @enumFromInt(value % Kind.COUNT),
            .player = @enumFromInt(value / Kind.COUNT),
        };
    }

    pub fn toInt(self: Piece) u8 {
        return @intFromEnum(self.kind) +
            @intFromEnum(self.player) * Kind.COUNT;
    }
};

pub fn getAvailableMoves(board: *const Self, origin: Tile) moves.AvailableMoves {
    return moves.AvailableMoves.new(board, origin);
}
