const Self = @This();

const std = @import("std");
const assert = std.debug.assert;

const Board = @import("Board.zig");
const Tile = Board.Tile;
const Piece = Board.Piece;

pub const Move = struct {
    destination: Tile,
    // ...add more fields when necessary
};

pub const AvailableMoves = struct {
    board: *const Board,
    origin: Tile,
    index: usize,

    pub fn next(self: *AvailableMoves) ?Move {
        const piece = self.board.get(self.origin) orelse
            return null;

        const rules = getMoveRules(piece.kind);

        while (self.index < rules.len) {
            const move = rules[self.index];
            self.index += 1;

            const destination = move.offset.applyTo(self.origin, piece) orelse {
                continue;
            };

            const context = Requirement.Context{
                .board = self.board,
                .piece = piece,
                .origin = self.origin,
                .destination = destination,
                .rule = move,
            };

            if (move.requirement.isSatisfied(context)) {
                return Move{
                    .destination = destination,
                };
            }
        }

        return null;
    }
};

pub const MoveRule = struct {
    offset: Offset,
    requirement: Requirement = .{},
    /// If piece to take is different to destination (eg. in en-passant).
    take_alt: ?Offset = null,
};

pub fn getMoveRules(piece: Piece.Kind) []const MoveRule {
    // TODO: Support all pieces obviously
    return switch (piece) {
        .pawn => &[_]MoveRule{
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
                .take_alt = .{ .real = .{ .rank = 0, .file = -1 } },
            },
            .{
                .offset = .{ .advance = .{ .rank = 1, .file = 1 } },
                .requirement = .{ .take = .always },
                .take_alt = .{ .real = .{ .rank = 0, .file = 1 } },
            },
        },
        .knight => &[_]MoveRule{
            .{ .offset = .{ .real = .{ .rank = -1, .file = -2 } } },
            .{ .offset = .{ .real = .{ .rank = -2, .file = -1 } } },
            .{ .offset = .{ .real = .{ .rank = -1, .file = 2 } } },
            .{ .offset = .{ .real = .{ .rank = -2, .file = 1 } } },
            .{ .offset = .{ .real = .{ .rank = 1, .file = -2 } } },
            .{ .offset = .{ .real = .{ .rank = 2, .file = -1 } } },
            .{ .offset = .{ .real = .{ .rank = 1, .file = 2 } } },
            .{ .offset = .{ .real = .{ .rank = 2, .file = 1 } } },
        },
        .king => &[_]MoveRule{
            .{ .offset = .{ .real = .{ .rank = -1, .file = -1 } } },
            .{ .offset = .{ .real = .{ .rank = -1, .file = 0 } } },
            .{ .offset = .{ .real = .{ .rank = -1, .file = 1 } } },
            .{ .offset = .{ .real = .{ .rank = 0, .file = -1 } } },
            .{ .offset = .{ .real = .{ .rank = 0, .file = 1 } } },
            .{ .offset = .{ .real = .{ .rank = 1, .file = -1 } } },
            .{ .offset = .{ .real = .{ .rank = 1, .file = 0 } } },
            .{ .offset = .{ .real = .{ .rank = 1, .file = 1 } } },
        },
        else => &[_]MoveRule{},
    };
}

/// Use `null` for any unrestricted fields.
const Requirement = struct {
    /// Whether a piece must take (`always`), must **not** take (`never`).
    take: ?enum { always, never } = null,
    /// Rank index, counting from home side (black:7 = white:0 and vice-versa).
    /// For a pawn's first move.
    home_rank: ?usize = null,

    // ...also possible to add a fn pointer field for any custom behavior
    // (eg. castling).

    pub fn isSatisfied(self: *const Requirement, context: Context) bool {
        // Can never take/overwrite own piece
        if (context.board.get(context.destination)) |piece_take| {
            if (piece_take.player == context.piece.player) {
                return false;
            }
        }

        return self.isTakeSatisfied(context) and
            self.isHomeRankSatisfied(context);
    }

    fn isTakeSatisfied(self: *const Requirement, context: Context) bool {
        const take = self.take orelse {
            return true;
        };

        const will_take = context.willTake();

        return switch (take) {
            .always => will_take == .take,
            .never => will_take == .no_take,
        };
    }

    fn isHomeRankSatisfied(self: *const Requirement, context: Context) bool {
        const home_rank = self.home_rank orelse {
            return true;
        };

        const actual_home_rank = if (context.piece.player == .white)
            context.origin.rank
        else
            Board.SIZE - context.origin.rank - 1;

        return home_rank == actual_home_rank;
    }

    pub const Context = struct {
        board: *const Board,
        piece: Piece,
        origin: Tile,
        destination: Tile,
        rule: MoveRule,

        pub fn willTake(self: *const Context) enum { invalid, take, no_take } {
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

        /// Assumes `self.destination` is an opposite piece, if
        /// `self.rule.take_alt` is `null`.
        // TODO: Change somehow to prevent the weird above assumption
        pub fn getTakeTile(self: *const Context) ?Tile {
            if (self.rule.take_alt) |take| {
                return take.applyTo(self.origin, self.piece);
            }
            return self.destination;
        }
    };
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
