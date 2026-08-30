const std = @import("std");
const ArrayList = std.ArrayList;
const print = std.debug.print;
const assert = std.debug.assert;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const camera = @import("camera.zig");
const Ray = camera.Ray;
const Color = @import("Color.zig");
const Hit = camera.Hit;
const Material = @import("material.zig").Material;

pub const World = struct {
    alloc: std.mem.Allocator,
    spheres: ArrayList(Sphere),
    materials: ArrayList(Material),

    const Self = @This();
    pub fn init(alloc: std.mem.Allocator) std.mem.Allocator.Error!Self {
        return .{
            .alloc = alloc,
            .spheres = try ArrayList(Sphere).initCapacity(alloc, 8),
            .materials = try ArrayList(Material).initCapacity(alloc, 8),
        };
    }

    pub fn deinit(self: *Self) void {
        self.materials.deinit(self.alloc);
        self.spheres.deinit(self.alloc);
    }

    pub fn drawSphere(self: *Self, translation: Vec3, radius: f64, material: *const Material) std.mem.Allocator.Error!void {
        try self.spheres.append(self.alloc, .{ .p = translation, .r = radius, .material = material });
    }

    pub fn addMaterial(self: *Self, material: Material) !*const Material {
        const mat = try self.materials.addOne(self.alloc);
        mat.* = material;
        return mat;
    }

    pub fn hit(self: *const Self, ray: *Ray) void {
        hitItems(self.spheres.items, ray);
    }

    fn hitItems(array: anytype, ray: *Ray) void {
        for (array) |item| {
            item.hit(ray);
        }
    }
};

const Sphere = struct {
    p: Vec3,
    r: f64,
    material: *const Material,

    const Self = @This();

    fn hit(self: Self, ray: *Ray) void {
        assert(self.r >= 0);
        const oc = self.p - ray.origin;
        const a = vec.dot(ray.direction, ray.direction);
        const h = vec.dot(ray.direction, oc);
        const c = vec.dot(oc, oc) - self.r * self.r;
        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return;
        }

        const sqrtd = @sqrt(discriminant);
        var root = (h - sqrtd) / a;
        if (!ray.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray.surrounds(root)) return;
        }

        ray.max_t = root;
        const p = ray.at(root);
        const normal = (p - self.p) / vec.splat(self.r);
        ray.hit = Hit.init(normal, p, ray, self.material);
    }
};
