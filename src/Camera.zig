const std = @import("std");
const rand = @import("main.zig").rand;
const Writer = std.Io.Writer;

const Color = @import("Color.zig");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const World = @import("world.zig").World;
const material = @import("material.zig");
const Material = material.Material;

const max_bounce_depth = 10;
const aspect_ratio = 16.0 / 9.0;
const image_width = 400;
const anti_aliacing_samples = 100;
const defocus_angle = 0.06;
const focus_dist = 10.0;
const vfov = 20.0;
const look_from = Vec3{ 13, 2, 3 };
const look_at = vec.zero;
const vup = Vec3{ 0, 1, 0 };

const w = vec.unitVector(&(look_from - look_at));
const u = vec.unitVector(&vec.cross(&vup, &w));
const v = vec.cross(&w, &u);
const theta = std.math.degreesToRadians(vfov);
const h = std.math.tan(theta / 2.0);
const pixel_samples_scale = vec.one / vec.splat(anti_aliacing_samples);
const image_height = blk: {
    const height: comptime_int = @trunc(@as(comptime_float, @floatFromInt(image_width)) / aspect_ratio);
    if (height < 1) break :blk 1 else break :blk height;
};
const defocus_radius = focus_dist * @tan(std.math.degreesToRadians(defocus_angle / 2.0));
const defocus_disk_u = u * vec.splat(defocus_radius);
const defocus_disk_v = v * vec.splat(defocus_radius);
const viewport_height = 2.0 * h * focus_dist;
const viewport_width = viewport_height * @as(comptime_float, image_width) / @as(comptime_float, image_height);
const viewport_u = vec.splat(viewport_width) * u;
const viewport_v = vec.splat(viewport_height) * -v;
const pixel_delta_u = viewport_u / vec.splat(image_width);
const pixel_delta_v = viewport_v / vec.splat(image_height);
const center = look_from;
const viewport_upper_left = center - (vec.splat(focus_dist) * w) - (viewport_u / vec.two) - (viewport_v / vec.two);
const pixel00_loc = @mulAdd(Vec3, vec.half, (pixel_delta_u + pixel_delta_v), viewport_upper_left);

pub const Camera = struct {
    alloc: std.mem.Allocator,
    io: std.Io,

    const Self = @This();
    pub fn init(alloc: std.mem.Allocator, io: std.Io) Self {
        return .{
            .alloc = alloc,
            .io = io,
        };
    }

    pub fn render(self: *const Self, world: *const World) !void {
        const file = std.Io.File.stdout();
        defer file.close(self.io);

        const pixels_buffer = try self.alloc.alloc(Color, image_width * image_height);
        defer self.alloc.free(pixels_buffer);
        var wbuf: [4096]u8 = undefined;
        var file_writer = file.writer(self.io, &wbuf);
        const writer = &file_writer.interface;
        var threads = try self.alloc.alloc(std.Thread, image_height);
        defer self.alloc.free(threads);
        for (0..image_height) |row| {
            threads[row] = try std.Thread.spawn(.{}, renderRow, .{ world, row, pixels_buffer });
        }

        for (threads) |t| {
            t.join();
        }

        try drawPixels(writer, pixels_buffer);
        try file_writer.flush();
    }

    fn renderRow(world: *const World, row: usize, pixels_buffer: []Color) void {
        for (0..image_width) |column| {
            var hit_value = vec.zero;
            for (0..anti_aliacing_samples) |_| {
                var ray = getRay(@floatFromInt(column), @floatFromInt(row));
                var color = vec.one;
                for (0..max_bounce_depth) |_| {
                    world.hit(&ray);
                    if (ray.hit) |hit| {
                        const scatter = hit.material.scatter(&hit, ray.direction) orelse {
                            color = vec.zero;
                            break;
                        };
                        ray = scatter.ray;
                        color *= scatter.color;
                    } else {
                        const unit_direction = vec.unitVector(&ray.direction);
                        const a = vec.splat(0.5 * (unit_direction[1] + 1.0));
                        color *= (vec.one - a) * vec.one + a * Vec3{ 0.5, 0.7, 1.0 };
                        break;
                    }
                }

                hit_value += color;
            }

            pixels_buffer[image_width * row + column] = Color.fromVec(hit_value * pixel_samples_scale);
        }
    }

    fn getRay(i: f64, j: f64) Ray {
        const offset = Vec3{ rand.float(f64) - 0.5, rand.float(f64) - 0.5, 0 };
        const pixel_sample = pixel00_loc + (vec.splat((i + offset[0])) * pixel_delta_u) + ((vec.splat(j + offset[1])) * pixel_delta_v);
        const origin = if (defocus_angle > 0) defocusDiskSample() else center;
        return .{ .origin = origin, .direction = pixel_sample - center };
    }

    fn defocusDiskSample() Vec3 {
        const p = vec.randomInUnitDisk(-1, 1);
        return center + (vec.splat(p[0]) * defocus_disk_u) + (vec.splat(p[1]) * defocus_disk_v);
    }
};

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,
    min_t: f64 = 0.001,
    max_t: f64 = std.math.inf(f64),
    hit: ?Hit = null,

    const Self = @This();

    pub fn at(self: *const Self, t: f64) Vec3 {
        return @mulAdd(Vec3, @splat(t), self.direction, self.origin);
    }

    pub fn surrounds(self: *const Self, t: f64) bool {
        return self.min_t < t and t < self.max_t;
    }
};

pub const Hit = struct {
    normal: Vec3,
    p: Vec3,
    material: *const Material,
    front_face: bool = false,
    const Self = @This();

    pub fn init(normal: *const Vec3, p: Vec3, ray: *Ray, m: *const Material) Self {
        const front_face = vec.dot(&ray.direction, normal) < 0;
        const hit_normal = if (front_face) normal.* else -normal.*;
        return Hit{ .normal = hit_normal, .p = p, .front_face = front_face, .material = m };
    }
};

fn drawPixels(writer: *Writer, pixels_buffer: []Color) !void {
    try writer.print("P6\n{d} {d}\n255\n", .{ image_width, image_height });
    for (pixels_buffer) |color| {
        const bytes = color.bytes();
        _ = try writer.write(&bytes);
    }
}
