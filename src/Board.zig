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

pub fn getAvailableMoves(board: *const Self, tile: Tile) AvailableMoves {
    return AvailableMoves{
        .board = board,
        .tile = tile,
        .index = 0,
    };
}

pub const AvailableMoves = struct {
    const Board = Self;

    board: *const Board,
    tile: Tile,
    index: usize,

    pub fn next(self: *AvailableMoves) ?Tile {
        const piece = self.board.get(self.tile) orelse
            return null;

        const moves = getMoves(piece.kind);

        while (self.index < moves.len) {
            const move = moves[self.index];
            self.index += 1;

            const destination = move.offset.applyTo(self.tile, piece) orelse {
                continue;
            };

            const context = Requirement.Context{
                .board = self.board,
                .piece = piece,
                .tile = self.tile,
                .move = move,
                .destination = destination,
            };

            if (move.requirement.isSatisfied(context)) {
                // TODO: Return some result type which includes `tile_future`
                // and whether any piece was taken (if different).
                // Possibly derived from `move`
                return destination;
            }
        }

        return null;
    }
};

fn getMoves(piece: Piece.Kind) []const Move {
    // TODO: Support all pieces obviously
    return switch (piece) {
        .pawn => &[_]Move{
            .{
                .offset = .{ .advance = .{ .rank = 1, .file = 0 } },
                .requirement = .{ .take = .never },
            },
            .{
                .offset = .{ .advance = .{ .rank = 2, .file = 0 } },
                .requirement = .{ .take = .never, .home_rank = 1 },
            },
            .{
                .offset = .{ .advance = .{ .rank = 1, .file = -1 } },
                .requirement = .{ .take = .always },
            },
            .{
                .offset = .{ .advance = .{ .rank = 1, .file = 1 } },
                .requirement = .{ .take = .always },
            },
            .{
                .offset = .{ .advance = .{ .rank = 1, .file = -1 } },
                .requirement = .{ .take = .always },
                .take = .{ .real = .{ .rank = 0, .file = -1 } },
            },
            .{
                .offset = .{ .advance = .{ .rank = 1, .file = 1 } },
                .requirement = .{ .take = .always },
                .take = .{ .real = .{ .rank = 0, .file = 1 } },
            },
        },
        else => &[_]Move{},
    };
}

const Move = struct {
    offset: Offset,
    requirement: Requirement,
    take: ?Offset = null,
};

/// An offset which is dependant on the piece's attributes (eg. color).
// TODO: (DO LATER) Depending on how many variants are added, this abstraction
// could possibly be removed or improved somehow.
const Offset = union(enum) {
    real: RealOffset,
    advance: RealOffset,

    pub fn applyTo(self: Offset, tile: Tile, piece: Piece) ?Tile {
        switch (self) {
            .real => |offset| {
                return offset.applyTo(tile);
            },
            .advance => |offset| {
                var real_offset = offset;
                real_offset.rank *= if (piece.player == .white) 1 else -1;
                return real_offset.applyTo(tile);
            },
        }
    }
};

// TODO: Rename?
// TODO: Document
const RealOffset = struct {
    const Board = Self;

    rank: isize,
    file: isize,

    pub fn applyTo(self: RealOffset, tile: Tile) ?Tile {
        const rank = @as(isize, @intCast(tile.rank)) + self.rank;
        const file = @as(isize, @intCast(tile.file)) + self.file;

        if (rank < 0 or file < 0 or rank >= Board.SIZE or file >= Board.SIZE) {
            return null;
        }

        return Tile{
            .rank = @intCast(rank),
            .file = @intCast(file),
        };
    }
};

/// Use `null` for any unrestricted fields.
const Requirement = struct {
    const Board = Self;

    /// Whether a piece must take (`always`), must **not** take (`never`).
    take: ?enum { always, never } = null,
    /// Rank index, counting from home side (black:7 = white:0 and vice-versa).
    /// For a pawn's first move.
    home_rank: ?usize = null,

    // TODO: Add custom field for special behaviour (eg. castling). IF NECESSARY

    pub fn isSatisfied(
        self: *const Requirement,
        context: Context,
    ) bool {
        // Can never take/overwrite own piece
        if (context.board.get(context.destination)) |piece_take| {
            if (piece_take.player == context.piece.player) {
                return false;
            }
        }

        if (self.take) |take| {
            const will_take = context.willTake();
            const satisfied = switch (take) {
                .always => will_take == .take,
                .never => will_take == .no_take,
            };
            if (!satisfied) {
                return false;
            }
        }

        if (self.home_rank) |home_rank| {
            const actual_home_rank = if (context.piece.player == .white)
                context.tile.rank
            else
                Board.SIZE - context.tile.rank - 1;
            if (home_rank != actual_home_rank) {
                return false;
            }
        }

        return true;
    }

    const Context = struct {
        board: *const Board,
        piece: Piece,
        tile: Tile,
        move: Move,
        destination: Tile,

        fn willTake(self: *const Context) enum { invalid, take, no_take } {
            const tile_take = self.getTakeTile() orelse {
                return .invalid;
            };
            const piece_take = self.board.get(tile_take) orelse {
                return .no_take;
            };
            if (piece_take.player == self.piece.player) {
                return .invalid;
            }
            return .take;
        }

        fn getTakeTile(self: *const Context) ?Tile {
            if (self.move.take) |take| {
                return take.applyTo(self.tile, self.piece);
            }
            return self.destination;
        }
    };
};
