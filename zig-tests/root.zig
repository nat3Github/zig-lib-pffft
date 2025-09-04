const std = @import("std");
pub const pffft = @import("pffft");
const Pfft = pffft.Pffft;

const float_tolerance = 0.001;

const test_fft_size = 512;
const test_seed = 234234234234;

fn alignOf(t: anytype) std.mem.Alignment {
    return @enumFromInt(@alignOf(t));
}

test "complex" {
    const alloc = std.testing.allocator;
    var xorrand = std.Random.DefaultPrng.init(test_seed);
    const ran = xorrand.random();

    const F = f64;
    const C = std.math.Complex(F);
    const input = try alloc.alignedAlloc(C, alignOf(C), test_fft_size);
    defer alloc.free(input);
    const output = try alloc.alignedAlloc(C, alignOf(C), test_fft_size);
    defer alloc.free(output);
    const validation = try alloc.alignedAlloc(C, alignOf(C), test_fft_size);
    defer alloc.free(validation);

    set_mem(C, .{ .re = 0.0, .im = 0.0 }, input);
    set_mem(C, .{ .re = 0.0, .im = 0.0 }, output);
    set_mem(C, .{ .re = 0.0, .im = 0.0 }, validation);

    for (input) |*f| {
        f.re = ran.float(F);
    }
    var fft = try Pfft(F, C).init(test_fft_size);

    fft.fft(input, output, null);
    fft.inverse_fft(output, validation, null);
    for (validation) |*v| {
        v.re = v.re / @as(F, @floatFromInt(test_fft_size));
        v.im = 0;
        // v.im / @as(F, @floatFromInt(size));
    }
    print(C, input[0..3]);
    print(C, validation[0..3]);
    const input_casted: []F = std.mem.bytesAsSlice(F, std.mem.sliceAsBytes(input));
    const validation_casted: []F = std.mem.bytesAsSlice(F, std.mem.sliceAsBytes(validation));
    try assert_eql(F, input_casted, validation_casted);
}
test "real" {
    const alloc = std.testing.allocator;
    var xorrand = std.Random.DefaultPrng.init(test_seed);
    const ran = xorrand.random();

    const F = f32;
    const C = std.math.Complex(F);
    const input = try alloc.alignedAlloc(F, alignOf(C), test_fft_size);
    defer alloc.free(input);
    const output = try alloc.alignedAlloc(C, alignOf(C), test_fft_size / 2);
    defer alloc.free(output);
    const validation = try alloc.alignedAlloc(F, alignOf(C), test_fft_size);
    defer alloc.free(validation);

    set_mem(F, 0, input);
    set_mem(C, .{ .re = 0.0, .im = 0.0 }, output);
    set_mem(F, 0, validation);

    for (input) |*f| {
        f.* = ran.float(F);
    }
    var fft = try Pfft(F, F).init(test_fft_size);

    fft.fft(input, output, null);
    fft.inverse_fft(output, validation, null);
    for (validation) |*v| {
        v.* = v.* / @as(F, @floatFromInt(test_fft_size));
    }
    print(F, input[0..3]);
    print(F, validation[0..3]);
    const input_casted: []F = std.mem.bytesAsSlice(F, std.mem.sliceAsBytes(input));
    const validation_casted: []F = std.mem.bytesAsSlice(F, std.mem.sliceAsBytes(validation));
    try assert_eql(F, input_casted, validation_casted);
}

fn set_mem(T: type, t: T, a: []T) void {
    for (a) |*x| {
        x.* = t;
    }
}
fn print(T: type, a: []T) void {
    for (a) |x| {
        std.log.warn("{any}", .{x});
    }
}

fn assert_eql(T: type, a: []T, b: []T) !void {
    for (a, b) |x, y| {
        if (!std.math.approxEqRel(T, x, y, float_tolerance)) return error.NotEqual;
    }
}
