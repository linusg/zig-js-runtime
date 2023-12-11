const std = @import("std");
const v8 = @import("v8");

const internal = @import("internal_api.zig");
const refl = internal.refl;
const NativeContext = internal.NativeContext;

const public = @import("api.zig");
const API = public.API;
const TPL = public.TPL;

const private = @import("private_api.zig");
const loadFn = private.loadFn;

// Compile and loading mechanism
// -----------------------------

// NOTE:
// The mechanism is based on 2 steps
// 1. The compile step at comptime will produce a list of APIs
// At this step we:
// - reflect the native struct to obtain type information (T_refl)
// - generate a loading function containing corresponding JS callbacks functions
// (constructor, getters, setters, methods)
// 2. The loading step at runtime will product a list of TPLs
// At this step we call the loading function into the runtime v8 (Isolate and globals),
// generating corresponding V8 functions and objects templates.

// Compile native types to native APIs
// which can be later loaded in JS.
// This function is called at comptime.
pub fn compile(comptime types: anytype) []API {
    comptime {

        // call types reflection
        const all_T = refl.do(types) catch unreachable;

        // generate APIs
        var apis: [all_T.len]API = undefined;
        inline for (all_T, 0..) |T_refl, i| {
            const loader = loadFn(T_refl, all_T);
            apis[i] = API{ .T_refl = T_refl, .load = loader };
        }

        return &apis;
    }
}

// The list of APIs and TPLs holds corresponding data,
// ie. TPLs[0] is generated by APIs[0].
// This is assumed by the rest of the loading mechanism.
// Therefore the content of thoses lists (and their order) should not be altered
// afterwards.
var TPLs: []TPL = undefined;

pub fn getTpl(index: usize) TPL {
    return TPLs[index];
}

// Load native APIs into a JS isolate
// This function is called at runtime.
pub fn load(
    nat_ctx: *NativeContext,
    isolate: v8.Isolate,
    globals: v8.ObjectTemplate,
    comptime apis: []API,
    tpls: []TPL,
) !void {
    inline for (apis, 0..) |api, i| {
        if (api.T_refl.proto_index == null) {
            tpls[i] = try api.load(nat_ctx, isolate, globals, null);
        } else {
            const proto_tpl = tpls[api.T_refl.proto_index.?]; // safe because apis are ordered from parent to child
            tpls[i] = try api.load(nat_ctx, isolate, globals, proto_tpl);
        }
    }
    TPLs = tpls;
}
