use gfx;
use gfx::*;

gfx_defines! {
    vertex Vertex {
        pos: [f32; 3] = "a_Pos",
        uv: [f32; 2] = "a_Uv",
    }

    constant CameraConsts {
        camera_pos: [f32; 4] = "u_CamPos",
        camera_forward: [f32; 4] = "u_CamForward",
        camera_up: [f32; 4] = "u_CamUp",
        camera_right: [f32; 4] = "u_CamRight",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),

        image_size: gfx::Global<[f32; 2]> = "u_ImageSize",
        time: gfx::Global<f32> = "u_Time",

        camera_consts: gfx::ConstantBuffer<CameraConsts> = "CameraConsts",
        out: gfx::RenderTarget<gfx::format::Rgba8> = "Target0",
    }
}
