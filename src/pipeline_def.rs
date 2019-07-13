use gfx;
use gfx::*;

gfx_defines! {
    vertex Vertex {
        pos: [f32; 2] = "a_Pos",
        uv: [f32; 2] = "a_Uv",
    }

    constant Locals {
        time: [f32; 2] = "u_Time", // scalar type (f32) doesn't work idk why
        image_size: [f32; 2] = "u_ImageSize",
        camera_to_world: [[f32; 4]; 4] = "u_CameraToWorld",
        //camera_pos:[f32;3]="u_CameraPos",
        //camera_orient:[[f32;3];3]="u_CameraOrient",
    }

     pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        locals: gfx::ConstantBuffer<Locals> = "Locals",
        out: gfx::RenderTarget<gfx::format::Rgba8> = "Target0",
    }
}
