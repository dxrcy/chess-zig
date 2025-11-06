const std = @import("std");
const assert = std.debug.assert;

const Board = @import("Board.zig");
const Tile = Board.Tile;
const Piece = Board.Piece;

pub const Move = struct {
    destination: Tile,
    take: ?Tile,
    move_alt: ?MoveAlt,

    const MoveAlt = struct {
        origin: Tile,
        destination: Tile,
    };
};

pub const AvailableMoves = struct {
    const Self = @This();

    board: *const Board,
    origin: Tile,
    ignore_check: bool,

    index: usize,
    line_index: usize,

    pub fn new(board: *const Board, origin: Tile, ignore_check: bool) Self {
        return Self{
            .board = board,
            .origin = origin,
            .ignore_check = ignore_check,
            .index = 0,
            .line_index = 0,
        };
    }

    pub fn next(self: *AvailableMoves) ?Move {
        const piece = self.board.get(self.origin) orelse
            return null;
        const rules = getMoveRules(piece.kind);

        while (self.index < rules.len) {
            const rule = rules[self.index];

            const move = self.tryApplyRule(rule, piece) orelse {
                continue;
            };
            if (!self.checkAllows(piece, move)) {
                continue;
            }
            return move;
        }
        return null;
    }

    fn checkAllows(self: *Self, piece: Piece, move: Move) bool {
        if (self.ignore_check or !self.board.isPlayerInCheck(piece.player)) {
            return true;
        }

        // PERF: Could reuse board if we really care
        var board = Board.new();
        @memcpy(&board.tiles, &self.board.tiles);
        board.applyMove(self.origin, move);

        return !board.isPlayerInCheck(piece.player);
    }

    fn tryApplyRule(self: *Self, rule: MoveRule, piece: Piece) ?Move {
        switch (rule.dest) {
            .offset => |offset| {
                self.updateIndex();

                const move = self.calculateMove(
                    rule,
                    piece,
                    offset.applyTo(self.origin, piece),
                ) orelse {
                    return null;
                };
                return move;
            },

            .line => |line| {
                assert(self.line_index <= Board.SIZE * Board.SIZE);
                self.line_index += 1;

                const move = self.calculateMove(
                    rule,
                    piece,
                    line.scale(self.line_index).applyTo(self.origin),
                ) orelse {
                    self.updateIndex();
                    return null;
                };

                if (self.board.get(move.destination) != null) {
                    self.updateIndex();
                }
                return move;
            },
        }
    }

    fn updateIndex(self: *Self) void {
        self.index += 1;
        self.line_index = 0;
    }

    fn calculateMove(
        self: *const Self,
        rule: MoveRule,
        piece: Piece,
        destination_opt: ?Tile,
    ) ?Move {
        const destination = destination_opt orelse {
            return null;
        };

        const context = Requirement.Context{
            .board = self.board,
            .piece = piece,
            .origin = self.origin,
            .destination = destination,
            .ignore_check = self.ignore_check,
            .rule = rule,
        };

        if (!rule.requirement.isSatisfied(context)) {
            return null;
        }

        // TODO: Extract as method?
        const move_alt = if (rule.move_alt) |move_alt| blk: {
            break :blk Move.MoveAlt{
                .origin = move_alt.origin.applyTo(self.origin, piece) orelse
                    unreachable,
                .destination = move_alt.destination.applyTo(self.origin, piece) orelse
                    unreachable,
            };
        } else null;

        return Move{
            .destination = destination,
            .take = context.getTakeTile(),
            .move_alt = move_alt,
        };
    }
};

pub const MoveRule = struct {
    dest: union(enum) {
        offset: Offset,
        line: RealOffset,
    },
    /// If piece to take is different to destination (eg. in en-passant).
    take_alt: ?Offset = null,
    /// If another piece of the same colour is moved (eg. in castling).
    move_alt: ?MoveAlt = null,
    requirement: Requirement = .{},

    const MoveAlt = struct {
        kind: Piece.Kind,
        origin: Offset,
        destination: Offset,
    };
};

pub fn getMoveRules(piece: Piece.Kind) []const MoveRule {
    return switch (piece) {
        .pawn => &[_]MoveRule{
            .{
                .dest = .{ .offset = .{ .advance = .{ .rank = 1, .file = 0 } } },
                .requirement = .{ .take = .never },
            },
            // First move, 2 tiles
            .{
                .dest = .{ .offset = .{ .advance = .{ .rank = 2, .file = 0 } } },
                .requirement = .{
                    .take = .never,
                    .home_rank = 1,
                    .free = .{ .advance = .{ .rank = 1, .file = 0 } },
                },
            },
            // Normal take
            .{
                .dest = .{ .offset = .{ .advance = .{ .rank = 1, .file = -1 } } },
                .requirement = .{ .take = .always },
            },
            .{
                .dest = .{ .offset = .{ .advance = .{ .rank = 1, .file = 1 } } },
                .requirement = .{ .take = .always },
            },
            // En-passant take
            .{
                .dest = .{ .offset = .{ .advance = .{ .rank = 1, .file = -1 } } },
                .take_alt = .{ .real = .{ .rank = 0, .file = -1 } },
                .requirement = .{ .take = .always },
            },
            .{
                .dest = .{ .offset = .{ .advance = .{ .rank = 1, .file = 1 } } },
                .take_alt = .{ .real = .{ .rank = 0, .file = 1 } },
                .requirement = .{ .take = .always },
            },
        },
        .king => &[_]MoveRule{
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -1, .file = -1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -1, .file = 0 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -1, .file = 1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 0, .file = -1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 0, .file = 1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 1, .file = -1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 1, .file = 0 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 1, .file = 1 } } } },
            // Castling (kingside)
            .{
                .dest = .{ .offset = .{ .real = .{ .rank = 0, .file = 2 } } },
                .move_alt = .{
                    .kind = .rook,
                    .origin = .{ .real = .{ .rank = 0, .file = 3 } },
                    .destination = .{ .real = .{ .rank = 0, .file = 1 } },
                },
                .requirement = .{
                    .take = .never,
                    .home_rank = 0,
                    .file = 4,
                    .not_check = true,
                    .not_attacked = &[_]Offset{
                        .{ .real = .{ .rank = 0, .file = 1 } },
                        .{ .real = .{ .rank = 0, .file = 2 } },
                    },
                },
                // TODO: (LATER) has never moved (king or rook) requires
                // tracking and storing piece movements (or movement count)
            },
            // Castling (queenside)
            .{
                .dest = .{ .offset = .{ .real = .{ .rank = 0, .file = -3 } } },
                .move_alt = .{
                    .kind = .rook,
                    .origin = .{ .real = .{ .rank = 0, .file = -4 } },
                    .destination = .{ .real = .{ .rank = 0, .file = -2 } },
                },
                .requirement = .{
                    .take = .never,
                    .home_rank = 0,
                    .file = 4,
                    .not_check = true,
                    .free = .{ .real = .{ .rank = 0, .file = -1 } },
                    .not_attacked = &[_]Offset{
                        .{ .real = .{ .rank = 0, .file = -1 } },
                        .{ .real = .{ .rank = 0, .file = -2 } },
                        .{ .real = .{ .rank = 0, .file = -3 } },
                    },
                },
            },
        },
        .knight => &[_]MoveRule{
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -1, .file = -2 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -2, .file = -1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -1, .file = 2 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = -2, .file = 1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 1, .file = -2 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 2, .file = -1 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 1, .file = 2 } } } },
            .{ .dest = .{ .offset = .{ .real = .{ .rank = 2, .file = 1 } } } },
        },
        .rook => &[_]MoveRule{
            .{ .dest = .{ .line = .{ .rank = -1, .file = 0 } } },
            .{ .dest = .{ .line = .{ .rank = 1, .file = 0 } } },
            .{ .dest = .{ .line = .{ .rank = 0, .file = -1 } } },
            .{ .dest = .{ .line = .{ .rank = 0, .file = 1 } } },
        },
        .bishop => &[_]MoveRule{
            .{ .dest = .{ .line = .{ .rank = -1, .file = -1 } } },
            .{ .dest = .{ .line = .{ .rank = -1, .file = 1 } } },
            .{ .dest = .{ .line = .{ .rank = 1, .file = -1 } } },
            .{ .dest = .{ .line = .{ .rank = 1, .file = 1 } } },
        },
        .queen => &[_]MoveRule{
            .{ .dest = .{ .line = .{ .rank = -1, .file = 0 } } },
            .{ .dest = .{ .line = .{ .rank = 1, .file = 0 } } },
            .{ .dest = .{ .line = .{ .rank = 0, .file = -1 } } },
            .{ .dest = .{ .line = .{ .rank = 0, .file = 1 } } },
            .{ .dest = .{ .line = .{ .rank = -1, .file = -1 } } },
            .{ .dest = .{ .line = .{ .rank = -1, .file = 1 } } },
            .{ .dest = .{ .line = .{ .rank = 1, .file = -1 } } },
            .{ .dest = .{ .line = .{ .rank = 1, .file = 1 } } },
        },
    };
}

/// Use `null` for any unrestricted fields.
const Requirement = struct {
    const Self = @This();

    /// Whether a piece must take (`always`), must **not** take (`never`).
    take: ?enum { always, never } = null,
    /// Rank index, counting from home side (black:7 = white:0 and vice-versa).
    /// For a pawn's first move.
    home_rank: ?usize = null,
    // NOTE: Temporary solution for castling, until pieces remember their
    // previous moves.
    file: ?usize = null,
    /// Requires this tile to be free. Treats out-of-bounds tiles as free.
    /// For en-passant.
    /// Similar to `MoveRule.position.line`.
    free: ?Offset = null,
    /// If `true`, rule is invalid while in check.
    // TODO: Use `not_attacked` with 0 offset instead
    not_check: bool = false,
    // TODO: Document
    not_attacked: []const Offset = &[0]Offset{},

    // ...also possible to add a fn pointer field for any custom behavior
    // (eg. castling).

    pub fn isSatisfied(self: *const Self, context: Context) bool {
        // Can never take/overwrite own piece
        if (context.board.get(context.destination)) |piece_take| {
            if (piece_take.player == context.piece.player) {
                return false;
            }
        }

        return self.isTakeSatisfied(context) and
            self.isHomeRankSatisfied(context) and
            self.isFileSatisfied(context) and
            self.isFreeSatisfied(context) and
            self.isNotCheckSatisfied(context) and
            self.isNotAttackedSatisfied(context) and
            self.isMoveAltSatisfied(context);
    }

    fn isTakeSatisfied(self: *const Self, context: Context) bool {
        const take = self.take orelse {
            return true;
        };

        const will_take = context.willTake();
        return switch (take) {
            .always => will_take == .take,
            .never => will_take == .no_take,
        };
    }

    fn isHomeRankSatisfied(self: *const Self, context: Context) bool {
        const home_rank = self.home_rank orelse {
            return true;
        };

        const actual_home_rank = if (context.piece.player == .white)
            context.origin.rank
        else
            Board.SIZE - context.origin.rank - 1;

        return home_rank == actual_home_rank;
    }

    fn isFileSatisfied(self: *const Self, context: Context) bool {
        const file = self.file orelse {
            return true;
        };

        return file == context.origin.file;
    }

    fn isFreeSatisfied(self: *const Self, context: Context) bool {
        const free = self.free orelse {
            return true;
        };

        const tile = free.applyTo(context.origin, context.piece) orelse {
            return true;
        };
        return context.board.get(tile) == null;
    }

    fn isNotCheckSatisfied(self: *const Self, context: Context) bool {
        if (!self.not_check) {
            return true;
        }

        if (context.ignore_check) {
            return true;
        }

        return !context.board.isPlayerInCheck(context.piece.player);
    }

    fn isNotAttackedSatisfied(self: *const Self, context: Context) bool {
        if (!self.not_check) {
            return true;
        }

        if (context.ignore_check) {
            return true;
        }

        for (self.not_attacked) |offset| {
            const target = offset.applyTo(context.origin, context.piece) orelse
                continue;

            if (context.board.isPlayerAttackedAt(context.piece.player, target)) {
                return false;
            }
        }

        return true;
    }

    fn isMoveAltSatisfied(self: *const Self, context: Context) bool {
        _ = self;
        const move_alt = context.rule.move_alt orelse {
            return true;
        };

        const origin = move_alt.origin.applyTo(context.origin, context.piece) orelse {
            return false;
        };
        const piece = context.board.get(origin) orelse {
            return false;
        };
        if (piece.kind != move_alt.kind or
            piece.player != context.piece.player)
        {
            return false;
        }

        const destination = move_alt.destination.applyTo(context.origin, context.piece) orelse {
            return false;
        };
        if (context.board.get(destination) != null) {
            return false;
        }

        return true;
    }

    pub const Context = struct {
        board: *const Board,
        piece: Piece,
        origin: Tile,
        destination: Tile,
        // TODO: Rename `ignore_attacked` or something.
        // And in `AvailableMoves` as well.
        ignore_check: bool,
        rule: MoveRule,

        pub fn willTake(self: *const Context) enum { invalid, take, no_take } {
            const tile_take = self.getTakeTileUnchecked() orelse {
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

        /// Returns `null` if tile is out-of-bounds **OR** empty.
        /// Asserts piece-to-take is opposite color.
        pub fn getTakeTile(self: *const Context) ?Tile {
            const tile = self.getTakeTileUnchecked() orelse
                return null;
            const piece = self.board.get(tile) orelse
                return null;
            assert(piece.player == self.piece.player.flip());
            return tile;
        }

        /// Returns `null` if tile is out-of-bounds.
        /// Does **NOT** check any status of piece-to-take.
        fn getTakeTileUnchecked(self: *const Context) ?Tile {
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
    const Self = @This();

    rank: isize,
    file: isize,

    pub fn applyTo(self: Self, tile: Tile) ?Tile {
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

    pub fn scale(self: Self, amount: usize) Self {
        return Self{
            .rank = self.rank * @as(isize, @intCast(amount)),
            .file = self.file * @as(isize, @intCast(amount)),
        };
    }
};
