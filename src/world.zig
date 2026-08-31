const std = @import("std");
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const camera = @import("camera.zig");
const Ray = camera.Ray;
const Hit = camera.Hit;
const Material = @import("material.zig").Material;

pub const Object = struct {
    ptr: *anyopaque,
    hit: *const fn (ptr: *anyopaque, ray: *Ray) void,

    fn create(object: anytype) Object {
        return .{
            .ptr = object,
            .hit = (struct {
                fn hit(ptr: *anyopaque, ray: *Ray) void {
                    const obj: @TypeOf(object) = @ptrCast(@alignCast(ptr));
                    obj.hit(ray);
                }
            }).hit,
        };
    }
};

pub const World = struct {
    alloc: std.mem.Allocator,
    objects: ArrayList(Object),
    materials: ArrayList(Material),

    const Self = @This();
    pub fn init(alloc: std.mem.Allocator) Self {
        return .{
            .alloc = alloc,
            .objects = ArrayList(Object).empty,
            .materials = ArrayList(Material).empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.materials.deinit(self.alloc);
        self.objects.deinit(self.alloc);
    }

    pub fn drawSphere(self: *Self, translation: Vec3, radius: f64, material: *const Material) std.mem.Allocator.Error!void {
        const sphere = try self.alloc.create(Sphere);
        sphere.* = .{ .p = translation, .r = radius, .material = material };
        try self.objects.append(self.alloc, Object.create(sphere));
    }

    pub fn addMaterial(self: *Self, material: Material) !*const Material {
        const mat = try self.materials.addOne(self.alloc);
        mat.* = material;
        return mat;
    }

    pub fn hit(self: *const Self, ray: *Ray) void {
        for (self.objects.items) |object| {
            object.hit(object.ptr, ray);
        }
    }
};

const Sphere = struct {
    p: Vec3,
    r: f64,
    material: *const Material,

    const Self = @This();

    pub fn hit(self: *const Self, ray: *Ray) void {
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
