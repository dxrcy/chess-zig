const Self = @This();

const std = @import("std");

const Board = @import("Board.zig");

active: Player,
cursor: Position,

const Player = enum {
    white,
    black,
};
const Position = struct {
    row: usize,
    col: usize,
};

const PIECE_LENGTH: usize = 3;
const PIECE_HEIGHT: usize = 3;

const PADDING_LEFT: usize = 3;
const PADDING_RIGHT: usize = 3;
const PADDING_TOP: usize = 1;
const PADDING_BOTTOM: usize = 1;

const CELL_LENGTH: usize = PIECE_LENGTH + PADDING_LEFT + PADDING_RIGHT;
const CELL_HEIGHT: usize = PIECE_HEIGHT + PADDING_TOP + PADDING_BOTTOM;

const styles = struct {
    const BOLD: u8 = 1;
};

const colors = struct {
    const FOREGROUND: u8 = 30;
    const BACKGROUND: u8 = 40;

    const BLACK: u8 = 0;
    const RED: u8 = 1;
    const GREEN: u8 = 2;
    const YELLOW: u8 = 3;
    const BLUE: u8 = 4;
    const MAGENTA: u8 = 5;
    const CYAN: u8 = 6;
    const WHITE: u8 = 7;
};

const edges = struct {
    const LEFT = "▌";
    const RIGHT = "▐";
    const TOP = "🬂";
    const BOTTOM = "🬭";
    const TOP_LEFT = "🬕";
    const TOP_RIGHT = "🬨";
    const BOTTOM_LEFT = "🬲";
    const BOTTOM_RIGHT = "🬷";
};

pub fn render(self: *Self, board: *const Board) void {
    self.clearScreen();

    for (0..Board.SIZE) |row| {
        for (0..CELL_HEIGHT) |cell_line| {
            for (0..Board.SIZE) |col| {
                const PIECE_START = PADDING_TOP;
                const PIECE_END = PADDING_TOP + PIECE_LENGTH - 1;

                self.setColor(row, col);

                if (cell_line < PIECE_START or cell_line > PIECE_END) {
                    if (cell_line == 0) {
                        self.printEmptyCellLine(row, col, .top);
                    } else if (cell_line == CELL_HEIGHT - 1) {
                        self.printEmptyCellLine(row, col, .bottom);
                    } else {
                        self.printEmptyCellLine(row, col, .middle);
                    }
                    continue;
                }

                const piece = board.get(row, col) orelse {
                    self.printEmptyCellLine(row, col, .middle);
                    continue;
                };

                const piece_line = cell_line - PIECE_START;
                const string = piece.string()[piece_line * PIECE_LENGTH ..][0..PIECE_LENGTH];

                self.printSide(row, col, .left);
                std.debug.print("{s}", .{string});
                self.printSide(row, col, .right);
            }

            std.debug.print("\n", .{});
        }
    }

    self.resetColor();
}

fn printEmptyCellLine(
    self: *Self,
    row: usize,
    col: usize,
    side: enum { top, bottom, middle },
) void {
    if (side == .middle) {
        self.printSide(row, col, .left);
        std.debug.print(" " ** PIECE_LENGTH, .{});
        self.printSide(row, col, .right);
        return;
    }

    const string =
        if (!self.atCursor(row, col))
            " " ** CELL_LENGTH
        else if (side == .top)
            edges.TOP_LEFT ++
                edges.TOP ** (CELL_LENGTH - 2) ++
                edges.TOP_RIGHT
        else
            edges.BOTTOM_LEFT ++
                edges.BOTTOM ** (CELL_LENGTH - 2) ++
                edges.BOTTOM_RIGHT;

    std.debug.print("{s}", .{string});
}

fn printSide(
    self: *Self,
    row: usize,
    col: usize,
    side: enum { left, right },
) void {
    const string =
        if (!self.atCursor(row, col))
            (if (side == .left)
                " " ** PADDING_LEFT
            else
                " " ** PADDING_RIGHT)
        else
            (if (side == .left)
                edges.LEFT ++ " " ** (PADDING_LEFT - 1)
            else
                " " ** (PADDING_RIGHT - 1) ++ edges.RIGHT);

    std.debug.print("{s}", .{string});
}

fn clearScreen(self: *Self) void {
    _ = self;
    std.debug.print("\x1b[0;0H\x1b[J", .{});
}

fn setColor(self: *Self, row: usize, col: usize) void {
    const is_even = (row + col) % 2 == 0;

    const fg = colors.FOREGROUND +
        if (self.atCursor(row, col))
            (if (self.active == .black)
                colors.RED
            else
                colors.BLUE)
        else if (is_even)
            colors.BLACK
        else
            colors.WHITE;

    const bg = colors.BACKGROUND +
        if (is_even)
            colors.WHITE
        else
            colors.BLACK;

    std.debug.print("\x1b[{}m", .{styles.BOLD});
    std.debug.print("\x1b[{d}m", .{fg});
    std.debug.print("\x1b[{d}m", .{bg});
}

fn resetColor(self: *Self) void {
    _ = self;
    std.debug.print("\x1b[0m", .{});
}

fn atCursor(self: *const Self, row: usize, col: usize) bool {
    return self.cursor.row == row and self.cursor.col == col;
}
