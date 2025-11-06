const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

const State = @import("State.zig");
const Player = State.Player;

const moves = @import("moves.zig");
const Move = moves.Move;
const AvailableMoves = moves.AvailableMoves;

pub const SIZE: usize = 8;
pub const MAX_PIECE_COUNT: usize = SIZE * 2 * Player.COUNT;

tiles: [SIZE * SIZE]TileEntry,
// TODO: Move to `State`
taken: [Piece.Kind.COUNT * Player.COUNT]u32,

// TODO: Make better
const TileEntry = packed struct(u6) {
    // TODO: Rename
    kind: enum(u1) { empty, full },
    data: packed union {
        empty: void,
        full: packed struct(u5) {
            changed: bool,
            kind: Piece.Kind,
            player: Player,
        },
    },

    const empty = @This(){
        .kind = .empty,
        .data = .{ .empty = {} },
    };
};

pub fn new() Self {
    var self = Self{
        .tiles = [_]TileEntry{.empty} ** SIZE ** SIZE,
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
        self.set(.{ .rank = rank, .file = 4 }, .{ .kind = .king, .player = player });
        self.set(.{ .rank = rank, .file = 3 }, .{ .kind = .queen, .player = player });
        self.set(.{ .rank = rank, .file = 5 }, .{ .kind = .bishop, .player = player });
        self.set(.{ .rank = rank, .file = 6 }, .{ .kind = .knight, .player = player });
        self.set(.{ .rank = rank, .file = 7 }, .{ .kind = .rook, .player = player });
    }

    for (0..SIZE * SIZE) |i| {
        switch (self.tiles[i].kind) {
            .full => {
                var full = &self.tiles[i].data.full;
                full.changed = false;
            },
            else => {},
        }
    }

    return self;
}

pub fn get(self: *const Self, tile: Tile) ?Piece {
    assert(tile.rank < SIZE);
    assert(tile.file < SIZE);

    const entry = self.tiles[tile.rank * SIZE + tile.file];

    switch (entry.kind) {
        .empty => return null,
        .full => {
            const full = entry.data.full;
            return Piece{
                .kind = full.kind,
                .player = full.player,
            };
        },
    }
}

pub fn set(self: *Self, tile: Tile, piece: ?Piece) void {
    assert(tile.rank < SIZE);
    assert(tile.file < SIZE);

    const entry = if (piece) |piece_unwrapped|
        TileEntry{
            .kind = .full,
            .data = .{ .full = .{
                .changed = true,
                .kind = piece_unwrapped.kind,
                .player = piece_unwrapped.player,
            } },
        }
    else
        TileEntry.empty;

    self.tiles[tile.rank * SIZE + tile.file] = entry;
}

pub fn hasChanged(self: *const Self, tile: Tile) bool {
    assert(tile.rank < SIZE);
    assert(tile.file < SIZE);

    const entry = self.tiles[tile.rank * SIZE + tile.file];

    switch (entry.kind) {
        .empty => return false,
        .full => {
            const full = entry.data.full;
            return full.changed;
        },
    }
}

pub fn getTaken(self: *const Self, piece: Piece) u32 {
    return self.taken[piece.toInt()];
}

pub fn addTaken(self: *Self, piece: Piece) void {
    self.taken[piece.toInt()] += 1;
}

// TODO: Create iterator for pieces/tiles?

pub fn getTileOfFirst(self: *const Self, target: Piece) ?Tile {
    for (0..SIZE) |rank| {
        for (0..SIZE) |file| {
            const tile = Tile{ .rank = rank, .file = file };
            const piece = self.get(tile) orelse
                continue;
            if (piece.eql(target)) {
                return tile;
            }
        }
    }
    return null;
}

pub fn isPieceAlive(self: *const Self, target: Piece) bool {
    return self.getTileOfFirst(target) != null;
}

pub fn getAvailableMoves(board: *const Self, origin: Tile) AvailableMoves {
    return AvailableMoves.new(board, origin, false);
}

pub fn getKing(self: *const Self, player: Player) Tile {
    return self.getTileOfFirst(.{
        .kind = .king,
        .player = player,
    }) orelse unreachable;
}

pub fn isPlayerAttackedAt(self: *const Self, player: Player, target: Tile) bool {
    for (0..SIZE) |rank| {
        for (0..SIZE) |file| {
            const tile = Tile{ .rank = rank, .file = file };

            const piece = self.get(tile) orelse
                continue;
            if (piece.player != player.flip()) {
                continue;
            }

            var available_moves = AvailableMoves.new(self, tile, true);
            while (available_moves.next()) |available| {
                const take = available.take orelse available.destination;
                if (take.eql(target)) {
                    return true;
                }
            }
        }
    }
    return false;
}

pub fn isPlayerInCheck(self: *const Self, player: Player) bool {
    return self.isPlayerAttackedAt(player, self.getKing(player));
}

pub fn applyMove(self: *Self, origin: Tile, move: Move) void {
    if (move.take) |take| {
        const piece_taken = self.get(take) orelse unreachable;
        self.addTaken(piece_taken);
        self.set(take, null);
    }

    if (move.move_alt) |move_alt| {
        self.movePieceToEmpty(move_alt.origin, move_alt.destination);
    }

    self.movePieceToEmpty(origin, move.destination);
}

fn movePieceToEmpty(self: *Self, origin: Tile, destination: Tile) void {
    const piece = self.get(origin) orelse unreachable;
    self.set(destination, piece);
    self.set(origin, null);
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

    pub fn string(self: Piece) *const [HEIGHT * WIDTH]u8 {
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
            \\[+])_(/_\
            ,
            .queen =>
            \\\^/]_[/_\
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
