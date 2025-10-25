const std = @import("std");
const assert = std.debug.assert;

const Board = @import("Board.zig");
const Ui = @import("Ui.zig");

pub fn main() !void {
    const board = Board.new();

    var ui = Ui{
        .active = .black,
        .cursor = .{ .row = 0, .col = 2 },
    };

    while (true) {
        ui.cursor.row = (ui.cursor.row + 1) % Board.SIZE;
        ui.active = if (ui.cursor.row > 3) .black else .white;

        ui.render(&board);

        std.Thread.sleep(500 * std.time.ns_per_ms);
    }
}
