const camera = @import("camera.zig");
const rand = @import("main.zig").rand;
const Hit = camera.Hit;
const Ray = camera.Ray;
const std = @import("std");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;

pub const Scatter = struct { ray: Ray, color: Vec3 };

pub const Lambertian = struct {
    color: Vec3 = vec.half,

    const Self = @This();

    fn scatter(self: *const Self, hit: *const Hit) Scatter {
        var scatter_direction = hit.normal + vec.randomUnitVectorWithRange(-1, 1);
        if (vec.nearZero(&scatter_direction)) {
            scatter_direction = hit.normal;
        }
        return .{ .ray = Ray{ .origin = hit.p, .direction = scatter_direction }, .color = self.color };
    }
};

pub const Metal = struct {
    color: Vec3,
    fuzz: f64,

    const Self = @This();

    fn scatter(self: *const Self, hit: *const Hit, direction: *const Vec3) ?Scatter {
        const ref = vec.reflect(direction, &hit.normal);
        const reflected = vec.unitVector(&ref) + (vec.splat(self.fuzz) * vec.randomUnitVectorWithRange(-1, 1));
        if (vec.dot(&reflected, &hit.normal) <= 0) {
            return null;
        }
        return Scatter{ .ray = Ray{ .origin = hit.p, .direction = reflected }, .color = self.color };
    }
};

pub const Dilectric = struct {
    refraction_index: f64,

    const Self = @This();

    fn scatter(self: *const Self, hit: *const Hit, direction: *const Vec3) Scatter {
        const ri = if (hit.front_face) 1.0 / self.refraction_index else self.refraction_index;
        const unit_direction = vec.unitVector(direction);
        const cos_theta = @min(vec.dot(&-unit_direction, &hit.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
        const dir = if (ri * sin_theta > 1.0 or reflectance(cos_theta, ri) > rand.float(f64)) vec.reflect(&unit_direction, &hit.normal) else vec.refract(&unit_direction, &hit.normal, ri);
        return .{ .color = vec.one, .ray = .{ .origin = hit.p, .direction = dir } };
    }

    fn reflectance(cosine: f64, refraction_index: f64) f64 {
        const r0 = (1 - refraction_index) / (1 + refraction_index);
        const r = r0 * r0;
        return @mulAdd(f64, (1 - r), std.math.pow(f64, (1 - cosine), 5), r);
    }
};

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dilectric,

    pub fn scatter(self: Material, hit: *const Hit, direction: *const Vec3) ?Scatter {
        return switch (self) {
            .lambertian => |l| l.scatter(hit),
            .metal => |m| m.scatter(hit, direction),
            .dielectric => |d| d.scatter(hit, direction),
        };
    }

    pub fn initLambertian(color: Vec3) Material {
        return Material{ .lambertian = .{ .color = color } };
    }

    pub fn initMetal(color: Vec3, fuzz: f64) Material {
        return Material{ .metal = .{ .color = color, .fuzz = fuzz } };
    }

    pub fn initDielectric(refraction_index: f64) Material {
        return Material{ .dielectric = .{ .refraction_index = refraction_index } };
    }
};
