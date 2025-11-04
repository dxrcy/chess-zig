const Self = @This();

const std = @import("std");
const assert = std.debug.assert;
const posix = std.posix;

const State = @import("State.zig");
const Board = State.Board;
const Piece = State.Board.Piece;
const Tile = State.Tile;

const Terminal = @import("Terminal.zig");

const Frame = @import("Frame.zig");

terminal: Terminal,
frames: [2]Frame,
current_frame: u1,
ascii: bool,

pub const tile_size = struct {
    pub const WIDTH: usize = Piece.WIDTH + PADDING_LEFT + PADDING_RIGHT;
    pub const HEIGHT: usize = Piece.HEIGHT + PADDING_TOP + PADDING_BOTTOM;

    const PADDING_LEFT: usize = 3;
    const PADDING_RIGHT: usize = 3;
    const PADDING_TOP: usize = 1;
    const PADDING_BOTTOM: usize = 1;
};

const Edge = enum {
    left,
    right,
    top,
    bottom,
    top_left,
    top_right,
    bottom_left,
    bottom_right,
};

const Rect = struct { y: usize, x: usize, h: usize, w: usize };

pub fn new(ascii: bool) Self {
    return Self{
        .terminal = Terminal.new(),
        .frames = [1]Frame{Frame.new()} ** 2,
        .current_frame = 0,
        .ascii = ascii,
    };
}

pub fn enter(self: *Self) !void {
    self.terminal.setAlternativeScreen(.enter);
    self.terminal.setCursorVisibility(.hidden);
    self.terminal.clearEntireScreen();
    self.terminal.flush();

    try self.terminal.saveTermios();
    var termios = self.terminal.original_termios orelse unreachable;
    termios.lflag.ICANON = false;
    termios.lflag.ECHO = false;
    termios.lflag.ISIG = false;
    try self.terminal.setTermios(termios);
}

pub fn exit(self: *Self) !void {
    self.terminal.setCursorVisibility(.visible);
    self.terminal.setAlternativeScreen(.exit);
    self.terminal.flush();

    try self.terminal.restoreTermios();
}

pub fn render(self: *Self, state: *const State) void {
    const frame = self.getForeFrame();

    // Board tile
    for (0..Board.SIZE) |rank| {
        for (0..Board.SIZE) |file| {
            const tile = Tile{ .rank = rank, .file = file };
            self.renderRectSolid(getTileRect(tile), .{
                .char = ' ',
                .bg = if (tile.isEven()) .black else .bright_black,
            });
        }
    }

    // Board piece icons
    for (0..Board.SIZE) |rank| {
        for (0..Board.SIZE) |file| {
            const tile = Tile{ .rank = rank, .file = file };
            const piece = state.board.get(tile) orelse
                continue;
            const string = piece.string();

            for (0..Piece.HEIGHT) |y| {
                for (0..Piece.WIDTH) |x| {
                    frame.set(
                        rank * tile_size.HEIGHT + y + tile_size.PADDING_TOP,
                        file * tile_size.WIDTH + x + tile_size.PADDING_LEFT,
                        .{
                            .char = string[y * Piece.HEIGHT + x],
                            .fg = if (piece.player == .white) .cyan else .red,
                            .bold = true,
                        },
                    );
                }
            }
        }
    }

    // Selected, available moves
    if (state.selected) |selected| {
        var available_moves = state.board.getAvailableMoves(selected);
        while (available_moves.next()) |available| {
            self.renderRectHighlight(getTileRect(available), .{
                .fg = .green,
            });
        }

        self.renderRectSolid(getTileRect(selected), .{
            .bg = .white,
        });
    }

    // Focus
    self.renderRectHighlight(getTileRect(state.focus), .{
        .fg = .bright_white,
        .bold = true,
    });
}

fn getTileRect(tile: Tile) Rect {
    return Rect{
        .y = tile.rank * tile_size.HEIGHT,
        .x = tile.file * tile_size.WIDTH,
        .h = tile_size.HEIGHT,
        .w = tile_size.WIDTH,
    };
}

fn renderRectSolid(
    self: *Self,
    rect: Rect,
    options: Frame.Cell.Options,
) void {
    var frame = self.getForeFrame();

    for (0..rect.h) |y| {
        for (0..rect.w) |x| {
            frame.set(rect.y + y, rect.x + x, options);
        }
    }
}

fn renderRectHighlight(
    self: *Self,
    rect: Rect,
    options: Frame.Cell.Options,
) void {
    var frame = self.getForeFrame();

    for (1..rect.w - 1) |x| {
        frame.set(
            rect.y,
            rect.x + x,
            options.join(.{ .char = self.getEdge(.top) }),
        );
        frame.set(
            rect.y + rect.h - 1,
            rect.x + x,
            options.join(.{ .char = self.getEdge(.bottom) }),
        );
    }

    for (1..rect.h - 1) |y| {
        frame.set(
            rect.y + y,
            rect.x,
            options.join(.{ .char = self.getEdge(.left) }),
        );
        frame.set(
            rect.y + y,
            rect.x + rect.w - 1,
            options.join(.{ .char = self.getEdge(.right) }),
        );
    }

    const corners = [_]struct { usize, usize, Edge }{
        .{ 0, 0, .top_left },
        .{ 0, 1, .top_right },
        .{ 1, 0, .bottom_left },
        .{ 1, 1, .bottom_right },
    };

    inline for (corners) |corner| {
        const y = corner[0];
        const x = corner[1];
        const edge = corner[2];
        frame.set(
            rect.y + y * (rect.h - 1),
            rect.x + x * (rect.w - 1),
            options.join(.{ .char = self.getEdge(edge) }),
        );
    }
}

pub fn draw(self: *Self) void {
    const Updates = struct {
        cursor: usize = 0,
        attr: usize = 0,
        print: usize = 0,
    };
    var updates = Updates{};

    for (0..Frame.HEIGHT) |y| {
        for (0..Frame.WIDTH) |x| {
            const cell_fore = self.getForeFrame().get(y, x);
            const cell_back = self.getBackFrame().get(y, x);

            if (cell_back.eql(cell_fore.*)) {
                continue;
            }

            if (self.terminal.updateCursor(.{ .row = y + 1, .col = x + 1 })) {
                updates.cursor += 1;
            }
            if (self.terminal.updateAttributes(cell_fore.attributes)) {
                updates.attr += 1;
            }

            self.terminal.print("{u}", .{cell_fore.char});
            self.terminal.cursor.col += 1;
            updates.print += 1;

            cell_back.* = cell_fore.*;
        }
    }

    inline for (@typeInfo(Updates).@"struct".fields, 0..) |field, i| {
        _ = self.terminal.updateCursor(.{ .row = Frame.HEIGHT + i + 1, .col = 1 });
        _ = self.terminal.updateAttributes(.{});

        self.terminal.print("\r\x1b[K", .{});
        self.terminal.print("{s}\t{}", .{
            field.name,
            @field(updates, field.name),
        });
    }

    self.terminal.flush();
    self.swapFrames();
}

pub fn getForeFrame(self: *Self) *Frame {
    return &self.frames[self.current_frame];
}
pub fn getBackFrame(self: *Self) *Frame {
    assert(@TypeOf(self.current_frame) == u1);
    return &self.frames[self.current_frame +% 1];
}
pub fn swapFrames(self: *Self) void {
    assert(@TypeOf(self.current_frame) == u1);
    self.current_frame +%= 1;
}

pub fn getEdge(self: *const Self, edge: Edge) u21 {
    return if (self.ascii) switch (edge) {
        .left, .right => '|',
        .top, .bottom => '-',
        else => '+',
    } else switch (edge) {
        .left => '▌',
        .right => '▐',
        .top => '🬂',
        .bottom => '🬭',
        .top_left => '🬕',
        .top_right => '🬨',
        .bottom_left => '🬲',
        .bottom_right => '🬷',
    };
}
