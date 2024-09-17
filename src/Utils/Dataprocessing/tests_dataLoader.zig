const std = @import("std");
const DataLoader = @import("./dataLoader.zig").DataLoader;
const fs = std.fs;
test "DataLoader xNext Test" {
    var features = [_][3]f64{
        [_]f64{ 1.0, 2.0, 3.0 },
        [_]f64{ 4.0, 5.0, 6.0 },
    };

    var labels = [_]u8{ 1, 0 };

    var featureSlices: [2][]f64 = undefined;
    featureSlices[0] = &features[0];
    featureSlices[1] = &features[1];

    const labelSlice: []u8 = &labels;

    var loader = DataLoader(f64, u8){
        .X = &featureSlices,
        .y = labelSlice,
    };

    const x1 = loader.xNext() orelse unreachable;
    try std.testing.expectEqual(f64, @TypeOf(x1[0]));
    try std.testing.expectEqual(1.0, x1[0]);
    try std.testing.expectEqual(2.0, x1[1]);
    try std.testing.expectEqual(3.0, x1[2]);

    const x2 = loader.xNext() orelse unreachable;
    try std.testing.expectEqual(f64, @TypeOf(x2[0]));
    try std.testing.expectEqual(4.0, x2[0]);
    try std.testing.expectEqual(5.0, x2[1]);
    try std.testing.expectEqual(6.0, x2[2]);

    const x3 = loader.xNext();
    try std.testing.expectEqual(null, x3);

    const y1 = loader.yNext() orelse unreachable;
    try std.testing.expectEqual(u8, @TypeOf(y1));
    try std.testing.expectEqual(1, y1);

    const y2 = loader.yNext() orelse unreachable;
    try std.testing.expectEqual(u8, @TypeOf(y2));
    try std.testing.expectEqual(0, y2);

    const y3 = loader.yNext();
    try std.testing.expectEqual(null, y3);
}

test "splitCSVLine tests" {
    const allocator = std.testing.allocator;

    const originalLine: []const u8 = "1,2,3,4,5\n";
    std.debug.print("Original CSV line: {s}\n", .{originalLine});
    const csvLine = try allocator.alloc(u8, originalLine.len);
    defer allocator.free(csvLine);
    @memcpy(csvLine, originalLine);
    const loader = DataLoader(f64, u8);
    const result = try loader.splitCSVLine(csvLine, &allocator);
    defer allocator.free(result);
    std.debug.print("Split result length: {}\n", .{result.len});
    const expected_values = [_][]const u8{ "1", "2", "3", "4", "5" };
    for (result, 0..) |column, i| {
        std.debug.print("Column {}: {s}\n", .{ i, column });
        try std.testing.expect(std.mem.eql(u8, column, expected_values[i]));
    }
    try std.testing.expectEqual(result.len, 5);

    // Caso 2: Colonne vuote
    const emptyColumnsLine: []const u8 = "1,,3,,5\n";
    std.debug.print("Original CSV line (empty columns): {s}\n", .{emptyColumnsLine});
    const csvLineEmpty = try allocator.alloc(u8, emptyColumnsLine.len);
    defer allocator.free(csvLineEmpty);
    @memcpy(csvLineEmpty, emptyColumnsLine);
    const resultEmpty = try loader.splitCSVLine(csvLineEmpty, &allocator);
    defer allocator.free(resultEmpty);
    const expected_values_empty = [_][]const u8{ "1", "", "3", "", "5" };
    for (resultEmpty, 0..) |column, i| {
        std.debug.print("Column {}: {s}\n", .{ i, column });
        try std.testing.expect(std.mem.eql(u8, column, expected_values_empty[i]));
    }
    try std.testing.expectEqual(resultEmpty.len, 5);

    // Caso 3: Stringhe con spazi
    const spacesLine: []const u8 = "a, b, c , d ,e\n";
    std.debug.print("Original CSV line (with spaces): {s}\n", .{spacesLine});
    const csvLineSpaces = try allocator.alloc(u8, spacesLine.len);
    defer allocator.free(csvLineSpaces);
    @memcpy(csvLineSpaces, spacesLine);
    const resultSpaces = try loader.splitCSVLine(csvLineSpaces, &allocator);
    defer allocator.free(resultSpaces);
    const expected_values_spaces = [_][]const u8{ "a", " b", " c ", " d ", "e" };
    for (resultSpaces, 0..) |column, i| {
        std.debug.print("Column {}: {s}\n", .{ i, column });
        try std.testing.expect(std.mem.eql(u8, column, expected_values_spaces[i]));
    }
    try std.testing.expectEqual(resultSpaces.len, 5);

    // Caso 4: Nessuna nuova riga finale
    const noNewLine: []const u8 = "1,2,3,4,5";
    std.debug.print("Original CSV line (no newline): {s}\n", .{noNewLine});
    const csvLineNoNewLine = try allocator.alloc(u8, noNewLine.len);
    defer allocator.free(csvLineNoNewLine);
    @memcpy(csvLineNoNewLine, noNewLine);
    const resultNoNewLine = try loader.splitCSVLine(csvLineNoNewLine, &allocator);
    defer allocator.free(resultNoNewLine);
    const expected_values_no_newline = [_][]const u8{ "1", "2", "3", "4", "5" };
    for (resultNoNewLine, 0..) |column, i| {
        std.debug.print("Column {}: {s}\n", .{ i, column });
        try std.testing.expect(std.mem.eql(u8, column, expected_values_no_newline[i]));
    }
    try std.testing.expectEqual(resultNoNewLine.len, 5);

    // Caso 5: Delimitatori consecutivi (colonne vuote)
    const consecutiveDelimiters: []const u8 = ",,,,\n";
    std.debug.print("Original CSV line (consecutive delimiters): {s}\n", .{consecutiveDelimiters});
    const csvLineConsecutive = try allocator.alloc(u8, consecutiveDelimiters.len);
    defer allocator.free(csvLineConsecutive);
    @memcpy(csvLineConsecutive, consecutiveDelimiters);
    const resultConsecutive = try loader.splitCSVLine(csvLineConsecutive, &allocator);
    defer allocator.free(resultConsecutive);
    const expected_values_consecutive = [_][]const u8{ "", "", "", "", "" };
    for (resultConsecutive, 0..) |column, i| {
        std.debug.print("Column {}: {s}\n", .{ i, column });
        try std.testing.expect(std.mem.eql(u8, column, expected_values_consecutive[i]));
    }
    try std.testing.expectEqual(resultConsecutive.len, 5);
}

test "readCSVLine test with correct file flags" {
    const allocator = std.testing.allocator;
    const loader = DataLoader(f64, u8);

    const cwd = std.fs.cwd();

    const temp_file_name = "test.csv";

    var file = try cwd.createFile(temp_file_name, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    const csv_content: []const u8 = "1,2,3,4,5\n6,7,8,9,10\n";
    try file.writeAll(csv_content);

    try file.seekTo(0);

    var reader = file.reader();

    const lineBuf = try allocator.alloc(u8, 100);
    defer allocator.free(lineBuf);

    const firstLine = try loader.readCSVLine(&reader, lineBuf) orelse unreachable;
    std.debug.print("First line: {s}\n", .{firstLine});
    try std.testing.expect(std.mem.eql(u8, firstLine, "1,2,3,4,5"));

    const secondLine = try loader.readCSVLine(&reader, lineBuf) orelse unreachable;
    std.debug.print("Second line: {s}\n", .{secondLine});
    try std.testing.expect(std.mem.eql(u8, secondLine, "6,7,8,9,10"));

    const eofLine = try loader.readCSVLine(&reader, lineBuf);
    try std.testing.expect(eofLine == null);
}

test "fromCSV test with feature and label extraction" {
    var allocator = std.testing.allocator;
    var loader = DataLoader(f64, u8){
        .X = undefined,
        .y = undefined,
    };

    const file_name: []const u8 = "test.csv";
    const features = [_]usize{ 0, 1, 2, 3 };
    const featureCols: []const usize = &features;
    const labelCol: usize = 4;

    try loader.fromCSV(&allocator, file_name, featureCols, labelCol);

    try std.testing.expectEqual(loader.X.len, 2);
    try std.testing.expectEqual(loader.y.len, 2);

    try std.testing.expectEqual(loader.X[0][0], 1);
    try std.testing.expectEqual(loader.X[0][1], 2);
    try std.testing.expectEqual(loader.X[0][2], 3);
    try std.testing.expectEqual(loader.X[0][3], 4);

    try std.testing.expectEqual(loader.y[0], 5);

    try std.testing.expectEqual(loader.X[1][0], 6);
    try std.testing.expectEqual(loader.X[1][1], 7);
    try std.testing.expectEqual(loader.X[1][2], 8);
    try std.testing.expectEqual(loader.X[1][3], 9);

    try std.testing.expectEqual(loader.y[1], 10);

    loader.deinit(&allocator);

    // Eliminare il file temporaneo alla fine del test
    //try std.fs.cwd().deleteFile(file_name);
}
