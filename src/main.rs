use arr_macro::arr;
use gfx;
use gfx::traits::*;
use gfx::*;
use ggez::conf;
use ggez::event::{self, EventHandler};
use ggez::graphics;
use ggez::nalgebra::Point2;
use ggez::timer;
use ggez::{Context, ContextBuilder, GameResult};
use num;

static FRAGMENT_GLSL: &[u8] = include_bytes!("./shader_fragment.glslf");
static VERTEX_GLSL: &[u8] = include_bytes!("./shader_vertex.glslv");

fn main() -> GameResult<()> {
    // Make a Context and an EventLoop.
    let (mut ctx, mut event_loop) = ContextBuilder::new("Raymarcher", "Dmitry")
        .window_setup(conf::WindowSetup {
            title: "Fractal Raymarcher".to_owned(),
            samples: conf::NumSamples::Zero,
            vsync: true,
            transparent: false,
            icon: "".to_owned(),
            srgb: true,
        })
        .window_mode(conf::WindowMode {
            width: 800.0,
            height: 600.0,
            maximized: false,
            fullscreen_type: conf::FullscreenType::Windowed,
            borderless: false,
            min_width: 0.0,
            max_width: 0.0,
            min_height: 0.0,
            max_height: 0.0,
            hidpi: false,
            resizable: true,
        })
        .build()?;

    // Create an instance of your event handler.
    // Usually, you should provide it with the Context object to
    // use when setting your game up.
    let mut my_game = MyGame::new();

    // Run!
    match event::run(&mut ctx, &mut event_loop, &mut my_game) {
        Ok(_) => println!("Exited cleanly"),
        Err(e) => println!("Error occured: {}", e),
    }
    Ok(())
}

struct MyGame {
    fps_text_cached: [graphics::Text; 99],
    locals: Locals,
}

impl MyGame {
    fn new() -> Self {
        let mut cached_fps_text = arr![graphics::Text::default();99];
        for (i, item) in cached_fps_text.iter_mut().enumerate() {
            let font = graphics::Font::default();
            let text = graphics::Text::new((i.to_string(), font, 24.0));
            *item = text;
        }

        MyGame {
            fps_text_cached: cached_fps_text,
            locals: Locals { time: 0. },
        }
    }
}

gfx_defines! {
    vertex Vertex {
        pos: [f32; 2] = "a_Pos",
    }

    constant Locals {
        time: f32 = "u_Time",
        //camera_pos:[f32;3]="u_CameraPos",
        //camera_orient:[[f32;3];3]="u_CameraOrient",
    }

     pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        locals: gfx::ConstantBuffer<Locals> = "Locals",
        out: gfx::RenderTarget<gfx::format::Rgba8> = "Target0",
    }
}

impl EventHandler for MyGame {
    fn update(&mut self, _ctx: &mut Context) -> GameResult<()> {
        Ok(())
    }

    fn draw(&mut self, ctx: &mut Context) -> GameResult<()> {
        graphics::clear(ctx, [0., 0., 0., 1.].into());

        // do custom pipeline stuff
        let (factory, device, encoder, _depthview, colour_view) = graphics::gfx_objects(ctx);

        let pso = factory.create_pipeline_simple(VERTEX_GLSL, FRAGMENT_GLSL, pipe::new())?;

        let quad = &[
            Vertex { pos: [-0.5, -0.5] },
            Vertex { pos: [0.5, -0.5] },
            Vertex { pos: [0.5, 0.5] },
            Vertex { pos: [-0.5, 0.5] },
        ];
        let indices: &[u16] = &[0u16, 1, 2, 0, 2, 3];

        let (vertex_buffer, slice) = factory.create_vertex_buffer_with_slice(quad, indices);
        let data = pipe::Data {
            locals: factory.create_constant_buffer(1),
            out: gfx::memory::Typed::new(colour_view),
            vbuf: vertex_buffer,
        };
        //encoder.

        // ggez drawing
        let quad = graphics::MeshBuilder::new()
            .rectangle(
                graphics::DrawMode::fill(),
                graphics::Rect::new(0., 0., 80., 80.),
                graphics::WHITE,
            )
            .build(ctx)?;

        graphics::draw(ctx, &quad, (Point2::new(50.0, 50.0),))?;

        // draw fps
        graphics::draw(
            ctx,
            &self.fps_text_cached[num::clamp(timer::fps(ctx).round() as usize, 0, 99)],
            graphics::DrawParam::new()
                .color((1., 1., 1., 1.).into())
                .dest(Point2::new(0., 0.)),
        )?;

        graphics::present(ctx)?;
        Ok(())
    }
}
